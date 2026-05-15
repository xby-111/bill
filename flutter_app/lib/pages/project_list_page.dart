import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import 'bill_list_page.dart';
import 'add_bill_page.dart';
import 'statistics_page.dart';

/// 项目管理页面
class ProjectListPage extends StatefulWidget {
  const ProjectListPage({Key? key}) : super(key: key);

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage> {
  List<Project> _projects = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final projects = await apiService.getProjects();
      setState(() {
        _projects = projects;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载项目失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createProject() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ProjectDialog(),
    );

    if (result != null) {
      try {
        await apiService.createProject(
          name: result['name']!,
          description: result['description'],
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('项目创建成功')),
          );
          _loadProjects();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _editProject(Project project) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ProjectDialog(
        initialName: project.name,
        initialDescription: project.description,
      ),
    );

    if (result != null) {
      try {
        await apiService.updateProject(
          projectId: project.id,
          name: result['name'],
          description: result['description'],
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('项目更新成功')),
          );
          _loadProjects();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除项目"${project.name}"吗？\n此操作将删除项目下的所有账单！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await apiService.deleteProject(project.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('项目删除成功')),
          );
          _loadProjects();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. 现代化标题栏
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('项目管理', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                onPressed: _createProject,
                tooltip: '新建项目',
              ),
            ],
          ),

          // 2. 内容区
          _isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : _projects.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              '还没有项目',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _createProject,
                              icon: const Icon(Icons.add),
                              label: const Text('创建第一个项目'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.all(16),
                      // 使用 SliverGrid 自适应布局：手机单列(列表)，大屏多列(网格)
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 600, // 卡片最大宽度，超过则分列
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.5, // 宽长方形，保持列表项的感觉
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final project = _projects[index];
                            return Card(
                              // 网格布局由 spacing 控制间距，Card 内部无需 margin
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BillListPage(
                                        projectId: project.id,
                                        projectName: project.name,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.folder, color: Colors.orange.shade700),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  project.name,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (project.description != null && project.description!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text(
                                                      project.description!,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          // 更多操作按钮
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 'add_bill',
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.add_circle_outline, color: Colors.blue),
                                                    SizedBox(width: 12),
                                                    Text('记一笔'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'stats',
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.pie_chart_outline, color: Colors.purple),
                                                    SizedBox(width: 12),
                                                    Text('查看报表'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuDivider(),
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.edit_outlined),
                                                    SizedBox(width: 12),
                                                    Text('编辑'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.delete_outline, color: Colors.red),
                                                    SizedBox(width: 12),
                                                    Text('删除', style: TextStyle(color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'add_bill':
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddBillPage(defaultProjectId: project.id))).then((_) => _loadProjects());
                                                  break;
                                                case 'stats':
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => StatisticsPage(defaultProjectId: project.id)));
                                                  break;
                                                case 'edit':
                                                  _editProject(project);
                                                  break;
                                                case 'delete':
                                                  _deleteProject(project);
                                                  break;
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildInfoChip(Icons.receipt_long, '${project.billCount} 笔账单'),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.push(context, MaterialPageRoute(builder: (_) => BillListPage(projectId: project.id, projectName: project.name)));
                                            },
                                            child: const Text('查看详情'),
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: _projects.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }
}

/// 项目创建/编辑对话框
class _ProjectDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;

  const _ProjectDialog({
    this.initialName,
    this.initialDescription,
  });

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName == null ? '创建项目' : '编辑项目'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '项目名称',
                hintText: '例如：装修项目、生活开销',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入项目名称';
                }
                if (value.length > 100) {
                  return '名称不能超过100个字符';
                }
                return null;
              },
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '项目描述（可选）',
                hintText: '简单描述项目内容',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value != null && value.length > 500) {
                  return '描述不能超过500个字符';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                if (_descriptionController.text.trim().isNotEmpty)
                  'description': _descriptionController.text.trim(),
              });
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
