enum UserRole { customer, technician, manager }

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.customer => 'Customer',
    UserRole.technician => 'Technician',
    // `manager` remains the internal compatibility value used by existing
    // sessions and APIs. The product workspace is deliberately called Admin.
    UserRole.manager => 'Admin',
  };

  String get workspaceDescription => switch (this) {
    UserRole.customer => 'Book trusted home services.',
    UserRole.technician => 'Manage jobs and grow your earnings.',
    UserRole.manager => 'Manage customers, teams and operations.',
  };
}
