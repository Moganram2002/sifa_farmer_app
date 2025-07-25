import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Required for RegistrationForm's internal timer
import '../models/user_data.dart';
import '../services/api_service.dart';
import '../utils/auth_storage.dart';
import '/pages/login_page.dart';
import '/libraries/copyright_footer.dart';
import '../libraries/registration_form_widget.dart'; // Make sure this path is correct

// A constant for the primary green color for easy reuse
const kPrimaryGreen = Color.fromARGB(255, 77, 157, 81); // A deep, natural green
const kLightGreen = Color(0xFFE8F5E9); // A light, earthy green for backgrounds


//==============================================================================
// MAIN DASHBOARD ROUTER WIDGET
// This widget checks the user's role and shows the correct dashboard view.
//==============================================================================
class DashboardPage extends StatelessWidget {
  final UserData currentUser;

  const DashboardPage({required this.currentUser, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (currentUser.roleId) {
      case 2: // Super Admin
        return _SuperAdminDashboardView(currentUser: currentUser);
      case 1: // Admin
        return _AdminDashboardView(currentUser: currentUser);
      case 0: // Regular User
      default:
        return _UserDashboardView(currentUser: currentUser);
    }
  }
}

//==============================================================================
// ADD USER PAGE (Used by Admin and Super Admin)
// This is now internal to the dashboard file and uses the registration library.
//==============================================================================
class _AddUserPage extends StatefulWidget {
  final int creatorId; // ID of the admin creating the user
  final VoidCallback onUserAdded; // Callback to refresh the user list

  const _AddUserPage({
    required this.creatorId,
    required this.onUserAdded,
  });

  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends State<_AddUserPage> {
  final _apiService = ApiService();

  // This function handles the data payload from the full registration form
  Future<void> _handleAdminUserCreation(RegistrationPayload payload) async {
    try {
      // The backend MUST set the new user's status to 0 (pending) by default.
      final response = await _apiService.createUserByAdmin(
        userData: payload.userData..addAll({'created_by': widget.creatorId.toString()}),
        profilePhoto: payload.profilePhotoBytes,
        idDocument: payload.idDocument,
      );

      if (!mounted) return;

      if (response.containsKey('id')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created and is pending approval.'), backgroundColor: Colors.green),
        );
        widget.onUserAdded(); // Refresh the dashboard list
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['error'] ?? 'Failed to create user.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New User'),
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24.0),
            constraints: const BoxConstraints(maxWidth: 700),
            // THIS IS THE KEY CHANGE:
            // We are now calling your reusable RegistrationForm widget
            child: RegistrationForm(
              apiService: _apiService,
              onFormSubmit: _handleAdminUserCreation,
              submitButtonText: 'Create User for Approval',
              isOtpFieldVisible: false, // Hides the OTP field for admins
              formTitle: 'New User Details',
            ),
          ),
        ),
      ),
    );
  }
}


//==============================================================================
// SUPER ADMIN IMPLEMENTATION
// Contains the full approval workflow.
//==============================================================================
class _SuperAdminDashboardView extends StatefulWidget {
  final UserData currentUser;
  const _SuperAdminDashboardView({required this.currentUser});

  @override
  _SuperAdminDashboardViewState createState() => _SuperAdminDashboardViewState();
}

class _SuperAdminDashboardViewState extends State<_SuperAdminDashboardView> {
  final _apiService = ApiService();
  int _mainIndex = 0;
  int _subIndex = 0;
  List<UserData> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _apiService.getAllUsers();
      if (!mounted) return;
      setState(() => _users = data.map((item) => UserData.fromJson(item)).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Failed to load data: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAddUser() {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => _AddUserPage(creatorId: widget.currentUser.id, onUserAdded: _fetchData),
    ));
  }
  
  void _editUser(UserData user) { /* Implement navigation to an Edit User page */ }
  
  void _deleteUser(int id) async { 
      try {
        await _apiService.deleteUser(id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User deactivated"), backgroundColor: Colors.orange));
        _fetchData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to deactivate user"), backgroundColor: Colors.red));
      }
  }
  
  void _makeAdmin(int id) async { 
      try {
        await _apiService.makeUserAdmin(id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User promoted to Admin"), backgroundColor: Colors.green));
        _fetchData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to promote user"), backgroundColor: Colors.red));
      }
  }
  
  void _logout() async { 
      await AuthStorage.clear();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => LoginPage()), (route) => false);
      }
  }

  Future<void> _approveUser(int userId) async {
    try {
      // Your API Service needs a method like this.
      await _apiService.updateUserStatus(userId, 1); // Status 1 for 'approved'
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User approved successfully."), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to approve user: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _declineUser(int userId) async {
    try {
      // For declining, we simply delete the user record.
      await _apiService.deleteUser(userId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User declined and removed."), backgroundColor: Colors.orange));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to decline user: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightGreen.withOpacity(0.5),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _mainIndex,
            onDestinationSelected: (index) => setState(() { _mainIndex = index; _subIndex = 0; }),
            backgroundColor: const Color(0xFF1B5E20),
            indicatorColor: kPrimaryGreen,
            unselectedIconTheme: const IconThemeData(color: Colors.white70, size: 28),
            selectedIconTheme: const IconThemeData(color: Colors.white, size: 28),
            trailing: const Expanded(child: Align(alignment: Alignment.bottomLeft, child: CopyrightFooter(color: Colors.white54))),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), label: Text('')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Container(
            width: 250,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: _buildSecondaryMenu(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, ${widget.currentUser.name}! (Super Admin)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryGreen)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoading ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen)) : _error != null ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red))) : _buildMainContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryMenu() {
    List<Widget> menuItems;
    int pendingCount = _users.where((u) => u.status == 0 && u.roleId == 0).length;
    switch (_mainIndex) {
      case 0: // Management
        menuItems = [
          Text("ADMINISTRATION", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: Badge(label: Text(pendingCount.toString()), isLabelVisible: pendingCount > 0, child: const Icon(Icons.hourglass_top_outlined, size: 20)),
            title: const Text("Pending Approvals"), selected: _subIndex == 0, selectedTileColor: kLightGreen, onTap: () => setState(() => _subIndex = 0),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, size: 20), title: const Text("Active Users"), selected: _subIndex == 1, selectedTileColor: kLightGreen, onTap: () => setState(() => _subIndex = 1),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined, size: 20), title: const Text("List Admins"), selected: _subIndex == 2, selectedTileColor: kLightGreen, onTap: () => setState(() => _subIndex = 2),
          ),
        ];
        break;
      case 1: // Settings
        menuItems = [ Text("GENERAL", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)), const SizedBox(height: 16), ListTile(leading: Icon(Icons.settings_applications, size: 20), title: Text("Site Settings"), selected: true, selectedTileColor: kLightGreen, onTap: () {}) ];
        break;
      default:
        menuItems = [];
    }
    return Column(children: [Expanded(child: ListView(children: menuItems)), const Divider(), ListTile(leading: Icon(Icons.logout, color: Colors.red.shade700), title: Text("Logout", style: TextStyle(color: Colors.red.shade700)), onTap: _logout)]);
  }

  Widget _buildMainContent() {
    if (_mainIndex == 0) {
      switch (_subIndex) {
        case 0:
          final pendingUsers = _users.where((u) => u.status == 0 && u.roleId == 0).toList();
          return _buildDataTable('Pending User Approvals', pendingUsers);
        case 1:
          final activeUsers = _users.where((u) => u.status == 1 && u.roleId == 0).toList();
          return _buildDataTable('Active Users', activeUsers);
        case 2:
          final admins = _users.where((u) => u.roleId == 1).toList();
          return _buildDataTable('System Administrators', admins);
      }
    }
    return const Center(child: Text("Site Settings Page"));
  }

  Widget _buildDataTable(String title, List<UserData> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87)),
            ElevatedButton.icon(onPressed: _navigateToAddUser, icon: const Icon(Icons.add), label: const Text("Add New"), style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            elevation: 2, clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(kLightGreen),
                  columns: const [DataColumn(label: Text('Name')), DataColumn(label: Text('Mobile')), DataColumn(label: Text('Status')), DataColumn(label: Text('Actions'))],
                  rows: data.map((user) => DataRow(cells: [
                    DataCell(Text(user.name)),
                    DataCell(Text(user.mobile ?? 'N/A')),
                    DataCell(_buildStatusChip(user.status)),
                    DataCell(user.status == 0 ? _buildPendingActions(user) : _buildActiveActions(user)),
                  ])).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPendingActions(UserData user) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      TextButton(onPressed: () => _approveUser(user.id), child: const Text('Approve', style: TextStyle(color: Colors.green))),
      TextButton(onPressed: () => _declineUser(user.id), child: const Text('Decline', style: TextStyle(color: Colors.red))),
    ]);
  }

  Widget _buildActiveActions(UserData user) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (user.roleId == 0) TextButton(onPressed: () => _makeAdmin(user.id), child: Text('Make Admin', style: TextStyle(color: kPrimaryGreen))),
      IconButton(icon: Icon(Icons.edit_outlined, size: 20, color: Colors.blue.shade700), onPressed: () => _editUser(user)),
      IconButton(icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700), onPressed: () => _deleteUser(user.id)),
    ]);
  }
  
  Widget _buildStatusChip(int status) {
    String label; Color color;
    switch (status) {
      case 0: label = 'Pending'; color = Colors.orange; break;
      case 1: label = 'Active'; color = Colors.green; break;
      default: label = 'Unknown'; color = Colors.grey;
    }
    return Chip(label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)), backgroundColor: color, side: BorderSide.none, padding: const EdgeInsets.symmetric(horizontal: 8));
  }
}

//==============================================================================
// ADMIN IMPLEMENTATION
// Shows only active users created by this admin.
//==============================================================================
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
  int _mainIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchMyUsers();
  }

  Future<void> _fetchMyUsers() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _apiService.getAdminUsers(widget.currentUser.id);
      if (!mounted) return;
      setState(() => _myUsers = data.map((item) => UserData.fromJson(item)).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Failed to load users: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAddUser() {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => _AddUserPage(creatorId: widget.currentUser.id, onUserAdded: _fetchMyUsers),
    ));
  }
  
  void _logout() async { /* Your existing logout logic */ }
  void _editUser(UserData user) { /* Implement navigation */ }
  void _deleteUser(int userId) { /* Your existing delete logic for admins */ }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightGreen.withOpacity(0.5),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _mainIndex,
            onDestinationSelected: (index) => setState(() => _mainIndex = index),
            backgroundColor: const Color(0xFF1B5E20),
            indicatorColor: kPrimaryGreen,
            unselectedIconTheme: const IconThemeData(color: Colors.white70, size: 28),
            selectedIconTheme: const IconThemeData(color: Colors.white, size: 28),
            trailing: const Expanded(child: Align(alignment: Alignment.bottomLeft, child: CopyrightFooter(color: Colors.white54))),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), label: Text('')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('')),
            ],
          ),
          Container(
            width: 250,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _buildSecondaryMenu(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, ${widget.currentUser.name}! (Admin)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryGreen)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!)) : _buildMainContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSecondaryMenu() {
    return Column(
      children: [
        Expanded(child: ListView(
          children: [
            Text("MANAGEMENT", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const ListTile(leading: Icon(Icons.person_outline, size: 20), title: Text("My Users"), selected: true, selectedTileColor: kLightGreen),
            ListTile(leading: const Icon(Icons.person_add_alt_1_outlined, size: 20), title: const Text("Add User"), onTap: _navigateToAddUser),
          ],
        )),
        const Divider(),
        ListTile(leading: Icon(Icons.logout, color: Colors.red.shade700), title: Text("Logout", style: TextStyle(color: Colors.red.shade700)), onTap: _logout),
      ],
    );
  }

  Widget _buildMainContent() {
    // Admins only see their active users.
    final activeUsers = _myUsers.where((user) => user.status == 1).toList();
    return _buildDataTable("Users Created By Me (Active)", activeUsers);
  }

  Widget _buildDataTable(String title, List<UserData> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87)),
            ElevatedButton.icon(onPressed: _navigateToAddUser, icon: const Icon(Icons.add), label: const Text("Add New User"), style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen, foregroundColor: Colors.white)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [DataColumn(label: Text('Name')), DataColumn(label: Text('Mobile')), DataColumn(label: Text('Actions'))],
                rows: data.map((user) => DataRow(cells: [
                  DataCell(Text(user.name)),
                  DataCell(Text(user.mobile ?? 'N/A')),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: Icon(Icons.edit_outlined, size: 20, color: Colors.blue.shade700), onPressed: () => _editUser(user)),
                    IconButton(icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700), onPressed: () => _deleteUser(user.id)),
                  ])),
                ])).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

//==============================================================================
// USER IMPLEMENTATION
// Simple welcome screen.
//==============================================================================
class _UserDashboardView extends StatelessWidget {
  final UserData currentUser;
  const _UserDashboardView({required this.currentUser});

  void _logout(BuildContext context) async {
    await AuthStorage.clear();
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Check user status to show appropriate message
    bool isPending = currentUser.status == 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
        title: const Text('User Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context), tooltip: "Logout")],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isPending ? Icons.hourglass_top_rounded : Icons.person, size: 80, color: isPending ? Colors.orange : kPrimaryGreen),
                    const SizedBox(height: 20),
                    Text('Welcome, ${currentUser.name}!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      isPending ? "Your account is pending approval." : "Your account is active.",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const CopyrightFooter(),
          ],
        ),
      ),
    );
  }
}