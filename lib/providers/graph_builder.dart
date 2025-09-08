import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/node_model.dart';

/// --- ACTION MODEL ---
abstract class GraphAction {
  void undo(GraphNotifier notifier);
  void redo(GraphNotifier notifier);
}

class AddNodeAction implements GraphAction {
  final Node node;
  AddNodeAction(this.node);

  @override
  void undo(GraphNotifier notifier) {
    notifier._removeNode(node.id, pushToHistory: false);
  }

  @override
  void redo(GraphNotifier notifier) {
    notifier._insertNode(node, pushToHistory: false);
  }
}

class DeleteNodeAction implements GraphAction {
  final List<Node> deletedNodes;
  DeleteNodeAction(this.deletedNodes);

  @override
  void undo(GraphNotifier notifier) {
    for (final n in deletedNodes) {
      notifier._insertNode(n, pushToHistory: false);
    }
  }

  @override
  void redo(GraphNotifier notifier) {
    for (final n in deletedNodes) {
      notifier._removeNode(n.id, pushToHistory: false);
    }
  }
}

class RenameNodeAction implements GraphAction {
  final int nodeId;
  final String oldLabel;
  final String newLabel;

  RenameNodeAction(this.nodeId, this.oldLabel, this.newLabel);

  @override
  void undo(GraphNotifier notifier) {
    notifier._renameNode(nodeId, oldLabel, pushToHistory: false);
  }

  @override
  void redo(GraphNotifier notifier) {
    notifier._renameNode(nodeId, newLabel, pushToHistory: false);
  }
}

class SetActiveAction implements GraphAction {
  final int oldActiveId;
  final int newActiveId;

  SetActiveAction(this.oldActiveId, this.newActiveId);

  @override
  void undo(GraphNotifier notifier) {
    notifier._setActive(oldActiveId, pushToHistory: false);
  }

  @override
  void redo(GraphNotifier notifier) {
    notifier._setActive(newActiveId, pushToHistory: false);
  }
}

/// --- STATE NOTIFIER ---
class GraphNotifier extends StateNotifier<List<Node>> {
  GraphNotifier() : super([Node(id: 1, label: "1", isActive: true)]) {
    _nextId = 2;
  }

  int _nextId = 2;

  final List<GraphAction> _undoStack = [];
  final List<GraphAction> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // ----------------- PUBLIC METHODS -----------------

  void addNode() {
    if (state.isEmpty) {
      final root = Node(id: 1, label: "1", isActive: true);
      _nextId = 2;
      state = [root];
      return;
    }

    final activeNode = state.firstWhere((n) => n.isActive);

    Node newNode;

    // Reuse last undone node if exists
    if (_redoStack.isNotEmpty && _redoStack.last is AddNodeAction) {
      newNode = (_redoStack.removeLast() as AddNodeAction).node;
    } else {
      newNode = Node(
        id: _nextId,
        label: _nextId.toString(),
        parentId: activeNode.id,
      );
      _nextId++;
    }

    // Add new node to state and parent's children
    state = [
      for (var node in state)
        if (node.id == activeNode.id)
          node.copyWith(children: [...node.children, newNode])
        else
          node,
      newNode
    ];

    // Record action
    _undoStack.add(AddNodeAction(newNode));
  }

  void setActive(int id) {
    final oldActive = state.firstWhere((n) => n.isActive, orElse: () => Node(id: -1, label: ''));
    if (oldActive.id == id) return;

    _setActive(id);

    _undoStack.add(SetActiveAction(oldActive.id, id));
    _redoStack.clear();
  }

  void renameNode(int id, String newLabel) {
    final node = state.firstWhere((n) => n.id == id);
    if (node.label == newLabel) return;

    _renameNode(id, newLabel);

    _undoStack.add(RenameNodeAction(id, node.label, newLabel));
    _redoStack.clear();
  }

  void deleteNode(int id) {
    if (id == 1) return; // root can't be deleted

    final idsToDelete = _getAllChildren(id);
    final deletedNodes = state.where((n) => idsToDelete.contains(n.id)).toList();

    for (final n in deletedNodes) {
      _removeNode(n.id);
    }

    _undoStack.add(DeleteNodeAction(deletedNodes));
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    action.undo(this);
    _redoStack.add(action);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final action = _redoStack.removeLast();
    action.redo(this);
    _undoStack.add(action);
  }

  // ----------------- INTERNAL HELPERS -----------------

  void _insertNode(Node node, {bool pushToHistory = true}) {
    state = [...state, node];
  }

  void _removeNode(int id, {bool pushToHistory = true}) {
    state = state.where((n) => n.id != id).toList();
  }

  void _renameNode(int id, String newLabel, {bool pushToHistory = true}) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(label: newLabel) else n
    ];
  }

  void _setActive(int id, {bool pushToHistory = true}) {
    state = [
      for (final n in state)
        n.copyWith(isActive: n.id == id)
    ];
  }

  List<int> _getAllChildren(int id) {
    final toDelete = <int>[];
    void helper(int parentId) {
      toDelete.add(parentId);
      for (final n in state.where((n) => n.parentId == parentId)) {
        helper(n.id);
      }
    }

    helper(id);
    return toDelete;
  }
}

// ----------------- PROVIDER -----------------
final graphProvider = StateNotifierProvider<GraphNotifier, List<Node>>(
  (ref) => GraphNotifier(),
);
