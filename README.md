# NodeFlow - Graph Builder Flutter App

NodeFlow is a Flutter application for building, visualizing, and interacting with tree-like graph structures. The app allows users to create nodes, connect them as parent-child relationships, rename nodes, and manage undo/redo history. It is designed for intuitive node management and interactive graph layouts.

---

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Node Model](#node-model)
- [State Management](#state-management)
- [Graph Layout](#graph-layout)
- [Undo/Redo System](#undoredo-system)
- [UI / Screens](#ui--screens)
- [Dependencies](#dependencies)
- [Usage](#usage)
- [Notes](#notes)
- [Author](#author)

---

## Features

- **Add Node:** Add a child to the active node.
- **Delete Node:** Delete a node and its subtree (root cannot be deleted).
- **Rename Node:** Rename any node.
- **Set Active Node:** Tap a node to make it active; active node glows.
- **Undo/Redo:** Full action history for add, delete, rename, and set active.
- **Tree Layout:** Automatic node placement in a hierarchical tree.
- **Interactive Viewer:** Zoom and pan around the graph.
- **Root Node Fallback:** If no node is active, root node is the default.

---

## Project Structure

```
lib/
├── main.dart              # Entry point
├── screens/
│   └── graph_screen.dart  # Main graph visualization UI
├── models/
│   └── node_model.dart    # Node data model
└── providers/
    └── graph_builder.dart # Graph state management and undo/redo logic
```

---

## Node Model

```dart
class Node {
  final int id;
  final String label;
  final int? parentId;
  final bool isActive;
  final List<Node> children;

  Node({required this.id, required this.label, this.parentId, this.isActive = false, this.children = const []});

  Node copyWith({int? id, String? label, int? parentId, bool? isActive, List<Node>? children}) { ... }
}
```

- Each node stores its **ID, label, parent, active status, and children**.
- `copyWith` is used to safely create updated node copies for immutable state updates.

---

## State Management

- Implemented using **Riverpod** and `StateNotifier`.
- `GraphNotifier` manages the list of nodes and history stacks.

```dart
class GraphNotifier extends StateNotifier<List<Node>> {
  GraphNotifier() : super([Node(id: 1, label: "1", isActive: true)]) { ... }

  void addNode() { ... }
  void deleteNode(int id) { ... }
  void renameNode(int id, String newLabel) { ... }
  void setActive(int id) { ... }
  void undo() { ... }
  void redo() { ... }
}
```

- **Undo/Redo System:**
  - `GraphAction` abstract class for `AddNodeAction`, `DeleteNodeAction`, `RenameNodeAction`, `SetActiveAction`.
  - Actions are pushed to `_undoStack` and `_redoStack` for full history.
  - Adding a node after undo reuses the last undone node to maintain sequence.

---

## Graph Layout

- Automatic tree layout using **recursive positioning** of nodes.
- Parent nodes are centered above their children.
- **EdgePainter** draws **curved edges without arrowheads** connecting parent → child.
- Node colors vary by depth for visual clarity.

---

## UI / Screens

- **GraphScreen:** Main screen for interactive graph building.
  - Nodes are tappable (set active) and long-pressable (context menu).
  - Active node glows.
  - Floating Action Buttons:
    - **Add (+):** Adds child to active node.
    - **Undo / Redo:** Manage history.
    - **Delete:** Delete selected node (disabled for root).
    - **Help (?):** Shows instructions.
- **Context Menu:** Long-press a node to Add Child, Rename, or Delete.
- **Rename Dialog:** Popup dialog to edit node labels.
- **Depth Indicator:** Displays the depth of the tree on the top-right.

---

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  google_fonts: ^6.1.0
  flutter_animate: ^4.2.0
  path_provider: ^2.1.4
  share_plus: ^10.0.0
  cupertino_icons: ^1.0.8
```

---

## Usage

1. Clone the repository:
```bash
git clone <repo-url>
```
2. Install dependencies:
```bash
flutter pub get
```
3. Run the app:
```bash
flutter run
```
4. Interact with nodes:
   - Tap to select node.
   - Use **+** to add child, **undo/redo**, **delete**, or long-press for context menu.

---

## Notes

- Root node (`id=1`) **cannot be deleted**.
- Undo/Redo maintains **linear history**; adding a node after undo will reuse the last undone node.
- Default active node is root if no node is selected.

---

## Author

- Developed by: Bhimani Yatra
- Contact: bhimaniyatra@gmail.com

