import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../models/user_data.dart';
import '../services/api_service.dart';
import '../utils/auth_storage.dart';
import '/pages/login_page.dart';
import '/libraries/copyright_footer.dart';
import '../libraries/registration_form_widget.dart';
import '../services/app_config_service.dart';

const kPrimaryGreen = Color.fromARGB(255, 77, 157, 81);
const kLightGreen = Color(0xFFE8F5E9);

class DashboardPage extends StatelessWidget {
  final UserData currentUser;
  const DashboardPage({required this.currentUser, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (currentUser.roleId) {
      case 2:
        return _SuperAdminDashboardView(currentUser: currentUser);
      case 1:
        return _AdminDashboardView(currentUser: currentUser);
      default:
        return _UserDashboardView(initialUser: currentUser);
    }
  }
}

// --- Super Admin View (MODIFIED) ---
class _SuperAdminDashboardView extends StatefulWidget {
  final UserData currentUser;
  const _SuperAdminDashboardView({required this.currentUser});
  @override
  _SuperAdminDashboardViewState createState() =>
      _SuperAdminDashboardViewState();
}

class _SuperAdminDashboardViewState extends State<_SuperAdminDashboardView> {
  final _apiService = ApiService();
  List<UserData> _users = [];
  bool _isLoading = true;
  String? _error;
  bool _isAddingOrEditing = false;
  UserData? _editingUser;
  final Set<int> _selectedUserIds = {};
  int _currentViewIndex = 1;
  bool _isNavPanelVisible = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = (data as List).map((item) => UserData.fromJson(item)).toList();
        _selectedUserIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Failed to load data: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddUserForm() => setState(() {
    _editingUser = null;
    _isAddingOrEditing = true;
  });

  void _hideForm() => setState(() {
        _isAddingOrEditing = false;
        _editingUser = null;
      });

  void _switchView(int index) => setState(() {
        _currentViewIndex = index;
        _hideForm();
      });

  void _showEditUserForm(UserData user) async {
    setState(() => _isLoading = true);
    try {
      final fullUserDetails = await _apiService.getUserById(user.id);
      if (!mounted) return;
      setState(() {
        _editingUser = fullUserDetails;
        _isAddingOrEditing = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user: $e'), backgroundColor: Colors.grey.shade700));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFormSubmission(RegistrationPayload payload) async {
    final isEditing = _editingUser != null;
    setState(() => _isLoading = true);
    try {
      final response = isEditing
          ? await _apiService.updateUser(_editingUser!.id,
              userData: payload.userData,
              profilePhoto: payload.profilePhotoBytes,
              idDocumentBytes: payload.idDocumentBytes,
              idDocumentName: payload.idDocumentName)
          : await _apiService.createUserByAdmin(
              userData: payload.userData..addAll({'created_by': widget.currentUser.id.toString()}),
              profilePhoto: payload.profilePhotoBytes,
              idDocumentBytes: payload.idDocumentBytes,
              idDocumentName: payload.idDocumentName);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'User updated successfully!' : 'User created successfully!'),
          backgroundColor: Colors.green));
      _hideForm();
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.grey.shade700));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await AuthStorage.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
    }
  }

  Future<void> _approveUser(int userId) async {
    try {
      await _apiService.updateUserStatus(userId, 1);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User approved successfully."), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to approve user: $e"), backgroundColor: Colors.grey.shade700));
    }
  }

  Future<void> _declineUser(int userId) async {
    try {
      // This now calls the soft-delete endpoint which sets status to 2
      await _apiService.deleteUser(userId);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User declined and moved to inactive."), backgroundColor: Colors.grey));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to decline user: $e"), backgroundColor: Colors.grey.shade700));
    }
  }

  void _bulkDeactivateUsers() async {
    if (_selectedUserIds.isEmpty) return;
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deactivation'),
        content: Text(
            'Are you sure you want to deactivate ${_selectedUserIds.length} selected user(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Deactivate'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700)),
        ],
      ),
    );
    if (confirm != true) return;
    int successCount = 0;
    for (final id in _selectedUserIds) {
      try {
        await _apiService.deleteUser(id);
        successCount++;
      } catch (e) { /* Log errors if needed */ }
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$successCount user(s) deactivated."), backgroundColor: Colors.grey));
    _fetchData();
  }

  void _makeAdmin(int id) async {
    try {
      await _apiService.makeUserAdmin(id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("User promoted to Admin"), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to promote user"), backgroundColor: Colors.grey));
    }
  }

  void _removeAdmin(int id, String name) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Demotion'),
        content: Text('Are you sure you want to remove admin privileges for $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove Admin'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600)),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _apiService.removeAdmin(id);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin role removed successfully."), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to remove admin role."), backgroundColor: Colors.grey));
    }
  }

  Future<void> _reactivateUser(int userId) async {
    try {
      await _apiService.updateUserStatus(userId, 1);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User reactivated successfully."), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to reactivate user: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<String>(
          valueListenable: AppConfigService.appTitleNotifier,
          builder: (context, title, child) {
            return Text(title, style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        centerTitle: true,
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _fetchData,
          )
        ],
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isNavPanelVisible ? 250 : 0,
            curve: Curves.easeInOut,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildLeftNavigationPanel(),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _isNavPanelVisible = !_isNavPanelVisible;
              });
            },
            child: Container(
              height: double.infinity,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  _isNavPanelVisible ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen))
                        : _isAddingOrEditing ? _buildAddEditUserForm() : _buildMainContent(),
                  ),
                ),
                const CopyrightFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftNavigationPanel() {
    int pendingCount = _users.where((u) => u.status == 0 && u.roleId == 0).length;
    final iconColor = Colors.grey.shade700;

    return Container(
      width: 250,
      color: const Color(0xFFF1F8E9),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              children: [
                Text("ADMINISTRATION",
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: Badge(
                      label: Text(pendingCount.toString()),
                      isLabelVisible: pendingCount > 0,
                      child: Icon(Icons.hourglass_top_outlined, size: 20, color: iconColor)),
                  title:
                      const Text("Pending Approvals", style: TextStyle(color: Color.fromARGB(255, 96, 94, 94))),
                  selected: _currentViewIndex == 0,
                  selectedTileColor: kLightGreen,
                  onTap: () => _switchView(0),
                ),
                ListTile(
                  leading: Icon(Icons.person_outline, size: 20, color: iconColor),
                  title: const Text("Active Users", style: TextStyle(color: Color.fromARGB(255, 96, 94, 94))),
                  selected: _currentViewIndex == 1,
                  selectedTileColor: kLightGreen,
                  onTap: () => _switchView(1),
                ),
                ListTile(
                  leading: Icon(Icons.shield_outlined, size: 20, color: iconColor),
                  title: const Text("List Admins", style: TextStyle(color: Color.fromARGB(255, 96, 94, 94))),
                  selected: _currentViewIndex == 2,
                  selectedTileColor: kLightGreen,
                  onTap: () => _switchView(2),
                ),
                ListTile(
                  leading: Icon(Icons.person_off_outlined, size: 20, color: iconColor),
                  title: const Text("Inactive Users", style: TextStyle(color: Color.fromARGB(255, 96, 94, 94))),
                  selected: _currentViewIndex == 4,
                  selectedTileColor: kLightGreen,
                  onTap: () => _switchView(4),
                ),
                const Divider(height: 32),
                Text("GENERAL", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.settings_outlined, size: 20, color: iconColor),
                  title: const Text("Settings"),
                  selected: _currentViewIndex == 3,
                  selectedTileColor: kLightGreen,
                  onTap: () => _switchView(3),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: Icon(Icons.logout, color: iconColor),
              title: Text('Logout', style: TextStyle(color: Colors.grey.shade700)),
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome, ${widget.currentUser.name}!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryGreen)),
        const SizedBox(height: 20),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.grey.shade800)))
              : _buildMainContentSwitch(),
        ),
      ],
    );
  }

  Widget _buildMainContentSwitch() {
    switch (_currentViewIndex) {
      case 0:
        final pendingUsers = _users.where((u) => u.status == 0 && u.roleId == 0).toList();
        return _buildDataTable('Pending User Approvals', pendingUsers);
      case 1:
        // MODIFIED: Filter now only shows active REGULAR users
        final activeUsers = _users.where((u) => u.status == 1 && u.roleId == 0).toList();
        return _buildDataTable('Active Users', activeUsers);
      case 2:
        // MODIFIED: Filter now only shows active ADMINS
        final admins = _users.where((u) => u.status == 1 && u.roleId == 1).toList();
        return _buildDataTable('System Administrators', admins);
      case 3:
        return _buildSettingsView();
      case 4:
        final inactiveUsers = _users.where((u) => u.status == 2).toList();
        return _buildDataTable('Inactive Users', inactiveUsers);
      default:
        return const Center(child: Text("Select a view from the menu."));
    }
  }

  Widget _buildSettingsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Application Settings",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          child: ListTile(
            leading: Icon(Icons.title, color: Colors.grey.shade700),
            title: const Text("Header Title"),
            subtitle: ValueListenableBuilder<String>(
              valueListenable: AppConfigService.appTitleNotifier,
              builder: (context, title, child) => Text(title),
            ),
            trailing: ElevatedButton(
              child: const Text("Edit"),
              onPressed: () => _showEditDialog(
                title: "Edit Header Title",
                initialValue: AppConfigService.appTitleNotifier.value,
                onSave: (newValue) async {
                  try {
                    setState(() => _isLoading = true);
                    await _apiService.updateSettings(title: newValue);
                    await AppConfigService.setAppTitle(newValue);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title updated!"), backgroundColor: Colors.green));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          child: ListTile(
            leading: Icon(Icons.copyright, color: Colors.grey.shade700),
            title: const Text("Footer Copyright Text"),
            subtitle: ValueListenableBuilder<String>(
              valueListenable: AppConfigService.copyrightNotifier,
              builder: (context, text, child) => Text(text),
            ),
            trailing: ElevatedButton(
              child: const Text("Edit"),
              onPressed: () => _showEditDialog(
                title: "Edit Copyright Text",
                initialValue: AppConfigService.copyrightNotifier.value,
                onSave: (newValue) async {
                   try {
                    setState(() => _isLoading = true);
                    await _apiService.updateSettings(copyright: newValue);
                    await AppConfigService.setCopyrightText(newValue);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copyright updated!"), backgroundColor: Colors.green));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditDialog({
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onSave(controller.text);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataTable(String title, List<UserData> data) {
    final isPendingTable = title == 'Pending User Approvals';
    final isAdminTable = title == 'System Administrators';
    final isInactiveTable = title == 'Inactive Users';

    final numSelected = _selectedUserIds.where((id) => data.any((user) => user.id == id)).length;

    bool? getHeaderCheckboxState() {
      if (numSelected == 0) return false;
      if (numSelected == data.length && data.isNotEmpty) return true;
      return null;
    }

    void handleHeaderCheckboxTapped() {
      setState(() {
        if (numSelected > 0) {
          _selectedUserIds.removeWhere((id) => data.any((user) => user.id == id));
        } else {
          _selectedUserIds.addAll(data.map((user) => user.id));
        }
      });
    }

    List<DataColumn> columns = [
      const DataColumn(label: Text('S.No.')),
      const DataColumn(label: Text('Name')),
      const DataColumn(label: Text('Mobile')),
      const DataColumn(label: Text('Status')),
      const DataColumn(label: Text('Actions')),
      if (!isPendingTable && !isInactiveTable) const DataColumn(label: Text('Edit')),
      if (!isPendingTable && !isInactiveTable)
        DataColumn(
          label: Checkbox(
            tristate: true,
            value: getHeaderCheckboxState(),
            onChanged: (value) => handleHeaderCheckboxTapped(),
            activeColor: Colors.green,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87)),
            if (!isInactiveTable)
              Row(
                children: [
                  if (!isPendingTable)
                    ElevatedButton.icon(
                      onPressed: _selectedUserIds.isNotEmpty ? _bulkDeactivateUsers : null,
                      icon: const Icon(Icons.person_off_outlined, size: 18),
                      label: Text("Deactivate (${_selectedUserIds.length})"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                    ),
                  if (!isPendingTable) const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _showAddUserForm,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Add New"),
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: MaterialStateProperty.all(kLightGreen),
                  columns: columns,
                  rows: List.generate(data.length, (index) {
                    UserData user = data[index];
                    final isSelected = _selectedUserIds.contains(user.id);

                    List<DataCell> cells = [
                      DataCell(Text((index + 1).toString())),
                      DataCell(Text(user.name)),
                      DataCell(Text(user.mobile ?? 'N/A')),
                      DataCell(_superAdminBuildStatusChip(user.status, user.roleId)),
                      DataCell(_buildActionsCell(user, isPending: isPendingTable, isAdmin: isAdminTable)),
                    ];

                    if (!isPendingTable && !isInactiveTable) {
                      cells.add(
                        DataCell(
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade700),
                            tooltip: 'Edit User',
                            onPressed: () => _showEditUserForm(user),
                          ),
                        ),
                      );
                      cells.add(
                        DataCell(
                          Checkbox(
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedUserIds.add(user.id);
                                } else {
                                  _selectedUserIds.remove(user.id);
                                }
                              });
                            },
                            activeColor: Colors.green,
                          ),
                        ),
                      );
                    }

                    return DataRow(
                      cells: cells,
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCell(UserData user, {required bool isPending, required bool isAdmin}) {
    final isInactiveTable = _currentViewIndex == 4;

    if (isInactiveTable) {
      return TextButton(
        onPressed: () => _reactivateUser(user.id),
        child: const Text('Reactivate', style: TextStyle(color: Colors.blue)),
      );
    }
    if (isPending) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(
            onPressed: () => _approveUser(user.id),
            child: const Text('Approve', style: TextStyle(color: Colors.green))),
        const SizedBox(width: 8),
        TextButton(
            onPressed: () => _declineUser(user.id),
            child: Text('Decline', style: TextStyle(color: Colors.grey.shade700))),
      ]);
    }
    if (isAdmin) {
      return TextButton(
        onPressed: () => _removeAdmin(user.id, user.name),
        child: Text('Remove Admin', style: TextStyle(color: Colors.grey.shade700)),
      );
    }
    if (user.roleId == 0) {
      return TextButton(
          onPressed: () => _makeAdmin(user.id),
          child: const Text('Make Admin', style: TextStyle(color: Colors.green)));
    }
    return Container();
  }

  Widget _superAdminBuildStatusChip(int status, int roleId) {
    String label;
    Color color;
    if (roleId == 2) {
      label = 'Super Admin';
      color = Colors.blueGrey;
    } else if (roleId == 1) {
      label = 'Admin';
      color = kPrimaryGreen;
    } else {
      switch (status) {
        case 0:
          label = 'Pending';
          color = Colors.orange.shade700;
          break;
        case 1:
          label = 'Active';
          color = Colors.green;
          break;
        case 2:
          label = 'Inactive';
          color = Colors.grey.shade600;
          break;
        default:
          label = 'Unknown';
          color = Colors.grey;
      }
    }
    return Chip(
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: color,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8));
  }
  
  Widget _buildAddEditUserForm() {
    return SingleChildScrollView(
      child: Center(
        child: SizedBox(
          width: 700,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RegistrationForm(
                key: ValueKey(_editingUser?.id ?? 'add'),
                apiService: _apiService,
                onFormSubmit: _handleFormSubmission,
                submitButtonText: _editingUser != null ? 'Update User' : 'Create User',
                isOtpFieldVisible: _editingUser == null,
                formTitle: _editingUser != null ? 'Edit User Details' : 'Add New User',
                initialData: _editingUser?.toRegistrationData(),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                  onPressed: _hideForm, icon: const Icon(Icons.arrow_back), label: const Text("Back to List")),
            ],
          ),
        ),
      ),
    );
  }
}


class _AdminDashboardView extends StatefulWidget {
  final UserData currentUser;
  const _AdminDashboardView({required this.currentUser});
  @override
  _AdminDashboardViewState createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<_AdminDashboardView> {
  final _apiService = ApiService();
  List<UserData> _myUsers = [];
  bool _isLoading = true;
  String? _error;
  bool _isAddingOrEditing = false;
  UserData? _editingUser;
  bool _isNavPanelVisible = true;

  @override
  void initState() {
    super.initState();
    _fetchMyUsers();
  }

  Future<void> _fetchMyUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.getAdminUsers(widget.currentUser.id);
      if (!mounted) return;
      setState(() => _myUsers = (data as List).map((item) => UserData.fromJson(item)).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Failed to load users: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddUserForm() => setState(() {
        _editingUser = null;
        _isAddingOrEditing = true;
      });
  void _hideForm() => setState(() {
        _isAddingOrEditing = false;
        _editingUser = null;
      });

  void _showEditUserForm(UserData user) async {
    setState(() => _isLoading = true);
    try {
      final fullUserDetails = await _apiService.getUserById(user.id);
      if (!mounted) return;
      setState(() {
        _editingUser = fullUserDetails;
        _isAddingOrEditing = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user: $e'), backgroundColor: Colors.grey.shade700));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFormSubmission(RegistrationPayload payload) async {
    final isEditing = _editingUser != null;
    setState(() => _isLoading = true);
    try {
      final response = isEditing
          ? await _apiService.updateUser(_editingUser!.id,
              userData: payload.userData,
              profilePhoto: payload.profilePhotoBytes,
              idDocumentBytes: payload.idDocumentBytes,
              idDocumentName: payload.idDocumentName)
          : await _apiService.createUserByAdmin(
              userData: payload.userData..addAll({'created_by': widget.currentUser.id.toString()}),
              profilePhoto: payload.profilePhotoBytes,
              idDocumentBytes: payload.idDocumentBytes,
              idDocumentName: payload.idDocumentName);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(isEditing ? 'User updated!' : 'User created!'), backgroundColor: Colors.green));
      _hideForm();
      await _fetchMyUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.grey.shade700));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await AuthStorage.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<String>(
          valueListenable: AppConfigService.appTitleNotifier,
          builder: (context, title, child) {
            return Text(title, style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        centerTitle: true,
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMyUsers, tooltip: "Refresh")],
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isNavPanelVisible ? 250 : 0,
            curve: Curves.easeInOut,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildLeftNavigationPanel(),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _isNavPanelVisible = !_isNavPanelVisible;
              });
            },
            child: Container(
              height: double.infinity,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  _isNavPanelVisible ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _isAddingOrEditing ? _buildAddEditUserForm() : _buildMainContent(),
                  ),
                ),
                const CopyrightFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftNavigationPanel() {
    final iconColor = Colors.grey.shade700;
    return Container(
      width: 250,
      color: const Color(0xFFF1F8E9),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              children: [
                Text("MANAGEMENT", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.people_alt_outlined, size: 20, color: iconColor),
                  title: const Text("My Users"),
                  selected: true,
                  selectedTileColor: kLightGreen,
                  onTap: () => _hideForm(),
                ),
                const Divider(height: 32),
                Text("GENERAL", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.settings_outlined, size: 20, color: iconColor),
                  title: const Text("Settings"),
                  onTap: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text("Settings page not available for Admins."))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: Icon(Icons.logout, color: iconColor),
              title: Text('Logout', style: TextStyle(color: Colors.grey.shade700)),
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome, ${widget.currentUser.name}!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryGreen)),
        const SizedBox(height: 20),
        Expanded(
          child: _error != null ? Center(child: Text(_error!)) : _buildDataTable("Users Created By Me", _myUsers),
        ),
      ],
    );
  }

  Widget _buildDataTable(String title, List<UserData> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87)),
            ElevatedButton.icon(
                onPressed: _showAddUserForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add New User"),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(kLightGreen),
                  columns: const [
                    DataColumn(label: Text('S.No.')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Mobile')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Edit')),
                  ],
                  rows: List.generate(data.length, (index) {
                    UserData user = data[index];
                    return DataRow(cells: [
                      DataCell(Text((index + 1).toString())),
                      DataCell(Text(user.name)),
                      DataCell(Text(user.mobile ?? 'N/A')),
                      DataCell(_adminBuildStatusChip(user.status)),
                      DataCell(
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade700),
                          tooltip: "Edit",
                          onPressed: () => _showEditUserForm(user),
                        ),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _adminBuildStatusChip(int status) {
    String label;
    Color color;
    switch (status) {
      case 0:
        label = 'Pending';
        color = Colors.orange.shade700;
        break;
      case 1:
        label = 'Active';
        color = Colors.green;
        break;
      default:
        label = 'Unknown';
        color = Colors.grey;
    }
    return Chip(
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: color,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8));
  }

  Widget _buildAddEditUserForm() {
    return SingleChildScrollView(
      child: Center(
        child: SizedBox(
          width: 700,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RegistrationForm(
                key: ValueKey(_editingUser?.id ?? 'add-admin'),
                apiService: _apiService,
                onFormSubmit: _handleFormSubmission,
                submitButtonText: _editingUser != null ? 'Update User' : 'Create User',
                isOtpFieldVisible: _editingUser == null,
                formTitle: _editingUser != null ? 'Edit User Details' : 'Add New User',
                initialData: _editingUser?.toRegistrationData(),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                  onPressed: _hideForm, icon: const Icon(Icons.arrow_back), label: const Text('Back to List')),
            ],
          ),
        ),
      ),
    );
  }
}


class _UserDashboardView extends StatefulWidget {
  final UserData initialUser;
  const _UserDashboardView({required this.initialUser});

  @override
  State<_UserDashboardView> createState() => _UserDashboardViewState();
}

class _UserDashboardViewState extends State<_UserDashboardView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserData _currentUser;
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isInitiallyLoading = true;
  bool _isEditingProfile = false;

  Timer? _newsTimer;
  int _currentNewsIndex = 0;
  int _unreadNewsCount = 6;
  final List<String> _newsItems = [
    "Crop Insurance deadline extended until August 15!",
    "Water supply updated: 6 AM to 9 AM in Zone A.",
    "Rice market rates increased by ₹200/quintal.",
    "Tractor loan now 0% interest for 6 months.",
    "Soil testing starts this week at Agri offices.",
    "Free seed distribution starts Monday in Panchayat offices."
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
    _tabController = TabController(length: 2, vsync: this);

    if (_currentUser.status == 0) {
      Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_currentUser.status == 1 || !mounted) {
          timer.cancel();
        } else {
          _refreshUserStatus();
        }
      });
    } else {
      _startNewsTicker();
    }
    
    _initialRefresh();
  }

  void _startNewsTicker() {
    _newsTimer?.cancel(); 
    _newsTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentNewsIndex = (_currentNewsIndex + 1) % _newsItems.length;
      });
    });
  }
  
  Future<void> _initialRefresh() async {
    try {
      final updatedUser = await _apiService.getUserById(_currentUser.id);
      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
          AuthStorage.saveUser(updatedUser.toJson());
          if (_currentUser.status == 1) {
            _startNewsTicker();
          }
        });
      }
    } catch (e) {
      print("Failed to perform initial user refresh: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isInitiallyLoading = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _newsTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUserStatus() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final updatedUser = await _apiService.getUserById(_currentUser.id);
      if (!mounted) return;
      setState(() {
        _currentUser = updatedUser;
        AuthStorage.saveUser(updatedUser.toJson());
        if (_currentUser.status == 1) {
           _startNewsTicker();
        }
      });
    } catch (e) {
      print("Failed to refresh user status: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await AuthStorage.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
    }
  }

  void _openNewsBottomSheet() {
    setState(() {
      _unreadNewsCount = 0;
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: 350,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Latest News",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryGreen,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: _newsItems.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.fiber_manual_record, size: 12, color: kPrimaryGreen),
                  title: Text(_newsItems[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProfileUpdate(RegistrationPayload payload) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.updateUser(
        _currentUser.id,
        userData: payload.userData,
        profilePhoto: payload.profilePhotoBytes,
        idDocumentBytes: payload.idDocumentBytes,
        idDocumentName: payload.idDocumentName,
      );

      await _initialRefresh(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
        );
        setState(() {
          _isEditingProfile = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: ${e.toString().replaceAll('Exception: ', '')}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isPending = _currentUser.status == 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
        title: ValueListenableBuilder<String>(
          valueListenable: AppConfigService.appTitleNotifier,
          builder: (context, title, child) {
            return Text(title, style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: "Logout")
        ],
        bottom: _isInitiallyLoading || isPending
            ? null
            : TabBar(
                controller: _tabController,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'DASHBOARD', icon: Icon(Icons.dashboard_rounded)),
                  Tab(text: 'MY PROFILE', icon: Icon(Icons.person_rounded)),
                ],
              ),
      ),
      body: _isInitiallyLoading 
          ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen))
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: isPending
                          ? _buildPendingView()
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildApprovedDashboardView(),
                                _buildUserProfileView(),
                              ],
                            ),
                    ),
                    const CopyrightFooter(),
                  ],
                ),
                if (!isPending) _buildFloatingNewsTicker(),
              ],
            ),
    );
  }

  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 80, color: Colors.grey.shade600),
            const SizedBox(height: 20),
            Text('Welcome, ${_currentUser.name}!',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Chip(
              label: const Text(
                "Your account is pending approval",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
            const SizedBox(height: 20),
            const Text(
              "Your dashboard will be available here once an admin approves your registration. The app will check for updates automatically.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _openNewsBottomSheet,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: kPrimaryGreen),
                  const SizedBox(width: 10),
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_unreadNewsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_unreadNewsCount',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showImageDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              return progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator(color: kPrimaryGreen));
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Text("Could not load image."));
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileView() {

    final String baseImageUrl = _apiService.getBaseUrlForImages();
    final String? profilePhotoUrl = _currentUser.profileImagePath != null
        ? '$baseImageUrl/uploads/${_currentUser.profileImagePath!}'
        : null;
    final String? idDocumentUrl = _currentUser.idDocumentPath != null
        ? '$baseImageUrl/uploads/${_currentUser.idDocumentPath!}'
        : null;

    if (_isEditingProfile) {
      return _buildEditProfileForm();
    }

    Widget buildSectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kPrimaryGreen,
          ),
        ),
      );
    }

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width > 800 ? 700 : MediaQuery.of(context).size.width * 0.9,
        margin: const EdgeInsets.symmetric(vertical: 20.0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: ListView(
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green.shade100,
                backgroundImage: profilePhotoUrl != null
                    ? NetworkImage(profilePhotoUrl)
                    : null,
                child: profilePhotoUrl == null
                    ? const Icon(Icons.person, size: 50, color: kPrimaryGreen)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _currentUser.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            Center(
              child: Chip(
                label: const Text('Account Active', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green,
                side: BorderSide.none,
              ),
            ),

            buildSectionHeader("My Documents"),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text("View Photo"),
                    onPressed: profilePhotoUrl != null
                      ? () => _showImageDialog(profilePhotoUrl, "Profile Photo")
                      : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text("View ID"),
                     onPressed: idDocumentUrl != null
                      ? () => _showImageDialog(idDocumentUrl, "ID Document")
                      : null,
                  ),
                ),
              ],
            ),
            
            buildSectionHeader("Personal Details"),
            _buildProfileInfoField(Icons.person_outline, "Full Name", _currentUser.name),
            _buildProfileInfoField(Icons.wc_outlined, "Gender", _currentUser.gender ?? 'N/A'),
      
            buildSectionHeader("Contact & Address"),
            _buildProfileInfoField(Icons.phone_android_outlined, "Mobile Number", _currentUser.mobile ?? 'N/A'),
            _buildProfileInfoField(Icons.pin_drop_outlined, "Address", _currentUser.location ?? 'N/A'),

            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Edit Profile"),
              onPressed: () => setState(() => _isEditingProfile = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileForm() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width > 800 ? 700 : MediaQuery.of(context).size.width * 0.9,
          margin: const EdgeInsets.symmetric(vertical: 20.0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            children: [
              RegistrationForm(
                key: ValueKey(_currentUser.id), 
                apiService: _apiService,
                onFormSubmit: _handleProfileUpdate,
                submitButtonText: 'Save Changes',
                isOtpFieldVisible: false, 
                formTitle: 'Edit My Profile',
                initialData: _currentUser.toRegistrationData(),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(() => _isEditingProfile = false),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoField(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNewsTicker() {
    return Positioned(
      bottom: 60,
      right: 20,
      width: 350,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
          border: Border.all(color: Colors.green.shade700),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.newspaper, color: kPrimaryGreen),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Container(
                  key: ValueKey(_currentNewsIndex),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _newsItems[_currentNewsIndex],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.fade,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}