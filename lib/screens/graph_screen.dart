import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/graph_builder.dart';
import '../models/node_model.dart';
import 'package:google_fonts/google_fonts.dart';

class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key});

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(graphProvider);
    final graph = ref.read(graphProvider.notifier);

    // Layout constants
    const double radius = 25;
    const double hSpacing = 140;
    const double vSpacing = 120;
    const double padding = 60;

    // Build parent → children map
    final childrenById = <int, List<Node>>{};
    for (final n in nodes) {
      if (n.parentId != null) {
        (childrenById[n.parentId!] ??= []).add(n);
      }
    }
    for (final list in childrenById.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }

    final centers = <int, Offset>{};

    // Recursive tree layout
    double layoutTree(Node node, double x, double y) {
      final children = childrenById[node.id] ?? [];
      if (children.isEmpty) {
        centers[node.id] = Offset(x, y);
        return hSpacing;
      }

      double childX = x;
      final widths = <double>[];
      for (final c in children) {
        final w = layoutTree(c, childX, y + vSpacing);
        widths.add(w);
        childX += w;
      }

      final firstX = centers[children.first.id]!.dx;
      final lastX = centers[children.last.id]!.dx;
      centers[node.id] = Offset((firstX + lastX) / 2, y);
      return widths.reduce((a, b) => a + b);
    }

    // Layout roots
    final roots = nodes.where((n) => n.parentId == null).toList();
    double currentX = padding;
    for (final root in roots) {
      final width = layoutTree(root, currentX, padding);
      currentX += width;
    }

    // Compute max depth
    int computeMaxDepth(Node? node, Map<int, List<Node>> childrenById) {
      if (node == null) return 0;
      final children = childrenById[node.id] ?? [];
      if (children.isEmpty) return 1;
      return 1 + children.map((c) => computeMaxDepth(c, childrenById)).reduce(max);
    }

    int maxDepth = 0;
    for (final root in roots) {
      maxDepth = max(maxDepth, computeMaxDepth(root, childrenById));
    }

    // Canvas size
    final maxX = centers.values.map((p) => p.dx).fold<double>(0, max);
    final maxY = centers.values.map((p) => p.dy).fold<double>(0, max);

    // Global shift
    const globalShift = Offset(40, 40);
    final shiftedCenters = {
      for (final e in centers.entries) e.key: e.value + globalShift,
    };

    final canvasWidth = maxX + padding * 2 + globalShift.dx * 2;
    final canvasHeight = maxY + padding * 2 + globalShift.dy * 2;

    final activeNode = nodes.firstWhere(
      (n) => n.isActive,
      orElse: () => Node(id: -1, label: ''),
    );

    final isRootActive = activeNode.id == 1;

    return Scaffold(
      backgroundColor: const Color(0xFFACDDDE),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          color: const Color(0xFF045D56),
          alignment: Alignment.center,
          child: Text(
            'NodeFlow - a Graph Builder',
            style: GoogleFonts.robotoSlab(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Interactive graph
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(1000),
            constrained: false,
            child: SizedBox(
              width: canvasWidth,
              height: canvasHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Edges without arrowheads
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EdgePainter(
                        nodes: nodes,
                        centers: shiftedCenters,
                        nodeRadius: radius,
                      ),
                    ),
                  ),

                  // Nodes
                  for (final n in nodes)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      left: shiftedCenters[n.id]!.dx - radius,
                      top: shiftedCenters[n.id]!.dy - radius,
                      child: GestureDetector(
                        onTap: () => graph.setActive(n.id),
                        onLongPress: () => _showContextMenu(context, n, graph),
                        child: Container(
                          width: (n.id == 1 ? radius * 2.4 : radius * 2),
                          height: (n.id == 1 ? radius * 2.4 : radius * 2),
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: (n.id == 1 ? radius * 2.4 : radius * 2),
                                height: (n.id == 1 ? radius * 2.4 : radius * 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 3,
                                  ),
                                ),
                              ),
                              Container(
                                width: (n.id == 1 ? radius * 1.8 : radius * 1.5),
                                height: (n.id == 1 ? radius * 1.8 : radius * 1.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _colorByDepth(n, nodes),
                                  boxShadow: [
                                    if (n.isActive)
                                      const BoxShadow(
                                        color: Colors.orangeAccent,
                                        blurRadius: 12,
                                        spreadRadius: 3,
                                      ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  n.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: (n.id == 1 ? 18 : 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Depth indicator - fixed top-right
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Text(
                "Depth: ${maxDepth > 0 ? maxDepth - 1 : 0}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'help',
            backgroundColor: Colors.blueGrey,
            onPressed: () => _showHelpSheet(context),
            child: const Icon(Icons.help_outline),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => graph.addNode(),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'undo',
            backgroundColor: Colors.orange,
            onPressed: () => graph.undo(),
            child: const Icon(Icons.undo),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'redo',
            backgroundColor: Colors.green,
            onPressed: () => graph.redo(),
            child: const Icon(Icons.redo),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'delete',
            backgroundColor: Colors.red.withOpacity(isRootActive ? 0.5 : 1),
            onPressed: isRootActive || activeNode.id == -1
                ? null
                : () => graph.deleteNode(activeNode.id),
            child: Icon(
              isRootActive ? Icons.block : Icons.delete,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Help & Instructions",
                style: GoogleFonts.robotoSlab(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text("• Tap on a node to select it."),
            const Text("• Glow on a node = Active node."),
            const Text("• '+' button adds a child to active node."),
            const Text("• Delete button removes selected node."),
            const Text("• Long-press a node for more options (Add, Rename, Delete)."),
            const SizedBox(height: 20),
            Text(
              "Need Help? Contact:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text("Email: your.email@example.com"),
            const Text("Phone: +91-XXXXXXXXXX"),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Node node, dynamic graph) {
    final isRoot = node.id == 1;
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add Child'),
            onTap: () {
              Navigator.pop(context);
              graph.setActive(node.id);
              graph.addNode();
            },
          ),
          ListTile(
            leading: Icon(
              isRoot ? Icons.block : Icons.delete,
              color: Colors.red,
            ),
            title: Text('Delete Node', style: TextStyle(color: Colors.red)),
            onTap: isRoot
                ? null
                : () {
                    Navigator.pop(context);
                    graph.deleteNode(node.id);
                  },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(context, node, graph);
            },
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Node node, dynamic graph) {
    final controller = TextEditingController(text: node.label);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Node'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Node Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              graph.renameNode(node.id, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Color _colorByDepth(Node node, List<Node> allNodes) {
    int depth = 0;
    Node? current = node;
    while (current?.parentId != null) {
      current = allNodes.firstWhere((n) => n.id == current!.parentId);
      depth++;
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[depth % colors.length];
  }
}

class _EdgePainter extends CustomPainter {
  final List<Node> nodes;
  final Map<int, Offset> centers;
  final double nodeRadius;

  _EdgePainter({
    required this.nodes,
    required this.centers,
    required this.nodeRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final child in nodes) {
      final pid = child.parentId;
      if (pid == null) continue;

      final parentCenter = centers[pid];
      final childCenter = centers[child.id];
      if (parentCenter == null || childCenter == null) continue;

      const double cornerRadius = 20;

      final midX = childCenter.dx;
      final midY = parentCenter.dy;

      final path = Path();
      path.moveTo(
        parentCenter.dx + (childCenter.dx > parentCenter.dx ? nodeRadius : -nodeRadius),
        parentCenter.dy,
      );

      final hx = midX - (childCenter.dx > parentCenter.dx ? cornerRadius : -cornerRadius);
      path.lineTo(hx, parentCenter.dy);

      path.quadraticBezierTo(
        midX,
        parentCenter.dy,
        midX,
        midY + (childCenter.dy > parentCenter.dy ? cornerRadius : -cornerRadius),
      );

      path.lineTo(
        midX,
        childCenter.dy - (childCenter.dy > parentCenter.dy ? nodeRadius : -nodeRadius),
      );

      canvas.drawPath(path, linePaint);
      // Removed arrowhead logic
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.centers != centers ||
        oldDelegate.nodeRadius != nodeRadius;
  }
}
