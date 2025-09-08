class Node {
  final int id;
  final String label;
  final int? parentId;
  final bool isActive;
  final List<Node> children;

  Node({
    required this.id,
    required this.label,
    this.parentId,
    this.isActive = false,
    this.children = const [],
  });

  Node copyWith({
    int? id,
    String? label,
    int? parentId,
    bool? isActive,
    List<Node>? children,
  }) {
    return Node(
      id: id ?? this.id,
      label: label ?? this.label,
      parentId: parentId ?? this.parentId,
      isActive: isActive ?? this.isActive,
      children: children ??
          this.children.map((child) => child.copyWith()).toList(),
    );
  }
}
