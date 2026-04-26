# BBBSCSMS Admin Web

A comprehensive **Barangay Community Management System** administrative portal built with Flutter and Firebase. This web application enables barangay administrators to manage community reports, resident registrations, and communicate announcements efficiently.

## Overview

BBBSCSMS Admin Web is the administrative interface for the Barangay Community Management System. It provides barangay officials with tools to:
- Review and manage community reports
- Verify and approve resident registrations
- Visualize complaints and incidents on an interactive map
- Track analytics and trends
- Broadcast announcements to residents
- Monitor pending activities with real-time notifications

## Features

### 📊 Analytics Dashboard
- Real-time statistics on community reports and resident registrations
- Visual charts and trends analysis
- Community insights and metrics

### 📋 Community Reports Management
- View all community reports with filters and search
- Approve/reject pending reports
- Track report status and resolution
- Detailed report information and categorization

### 🗺️ Complaint Map
- Interactive map visualization of all community complaints
- Geolocation-based incident tracking
- Visual heat mapping of problem areas

### 👥 Resident Verification
- Manage pending resident registrations
- Approve/reject new resident applications
- Update resident profiles and information
- Track resident status and history

### 📢 Announcements
- Create and broadcast announcements to residents
- Schedule announcements
- Track announcement views and engagement

### 🔔 Real-Time Notifications
- Instant notifications for pending reports and registrations
- Configurable alert system
- Auto-refresh notification counts

### 🔐 Authentication
- Secure admin login
- Role-based access control
- Logout functionality
- User profile management

## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Web)
- **Language**: Dart
- **Backend**: [Firebase](https://firebase.google.com/)
  - Firestore Database
  - Firebase Authentication
  - Firebase Storage
- **Database**: Supabase PostgreSQL
- **UI Library**: Material Design 3
- **Additional Libraries**:
  - `flutter_svg` - SVG asset support
  - `supabase_flutter` - Supabase client
  - `flutter_quill` - Rich text editing

## Project Structure

```
lib/
├── main.dart                 # Application entry point
├── screens/
│   ├── admin/
│   │   ├── admin_dashboard.dart           # Main admin dashboard
│   │   ├── reports_dashboard_screen.dart  # Reports management
│   │   ├── reports_map_screen.dart        # Interactive complaint map
│   │   ├── residents_screen.dart          # Resident verification
│   │   ├── analytics_screen.dart          # Analytics dashboard
│   │   └── announcements_screen.dart      # Announcements management
│   └── auth/
│       └── admin_login_screen.dart        # Admin authentication
├── services/                # Business logic and API calls
├── models/                  # Data models
└── Assets/                  # Images, SVGs, and static assets
```

## Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Dart SDK
- Firebase account
- Supabase account
- A code editor (VS Code, Android Studio, or IntelliJ)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Shard1/BBBSCSMS-admin-web.git
   cd BBBSCSMS-admin-web
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Download your Firebase configuration file
   - Place it in the appropriate location for web setup
   - Update your Firebase project credentials

4. **Configure Supabase**
   - Get your Supabase project URL and anonymous key
   - Update the configuration in your initialization file

5. **Run the application**
   ```bash
   flutter run -d chrome
   ```

## Usage

### Login
1. Navigate to the admin login screen
2. Enter your admin credentials
3. Click "Login" to access the dashboard

### Managing Reports
1. Go to "Community Reports" from the sidebar
2. View pending and approved reports
3. Click on a report to view details
4. Approve or reject reports as needed

### Verifying Residents
1. Navigate to "Resident Verification"
2. View pending resident applications
3. Review resident information
4. Approve or reject registrations

### Viewing Analytics
1. Click on "Analytics" in the main menu
2. View community statistics and trends
3. Analyze data through interactive charts

### Managing Announcements
1. Go to "Announcement" section
2. Create new announcements
3. Set target audience and schedule
4. Monitor announcement performance

### Checking Notifications
1. Click the notification bell icon in the header
2. View pending reports and registrations
3. Click "Open" to navigate to respective sections

## Configuration

### Environment Variables
- Firebase project configuration
- Supabase connection details
- API endpoints
- Authentication credentials

### Database Schema
The system uses Supabase PostgreSQL with tables for:
- `reports` - Community reports
- `residents` - Resident information
- `profiles` - User profiles
- `announcements` - System announcements

## Building for Production

```bash
# Build for web
flutter build web

# Build for Windows
flutter build windows

# Build for macOS
flutter build macos

# Build for Linux
flutter build linux
```

## API Integration

The application integrates with:
- **Firebase Authentication** - User authentication
- **Supabase Database** - Report, resident, and announcement data
- **Geolocation Services** - Map functionality

## Troubleshooting

### Build Issues
- Clear Flutter cache: `flutter clean`
- Regenerate files: `flutter pub get`
- Check Flutter doctor: `flutter doctor`

### Authentication Issues
- Verify Firebase credentials
- Check Supabase connection
- Ensure correct environment configuration

### Data Not Loading
- Verify database connection
- Check network connectivity
- Review Firestore/Supabase rules

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact & Support

For issues, questions, or suggestions:
- Create an issue on GitHub
- Contact the development team
- Visit the project wiki for additional documentation

## Roadmap

- [ ] Advanced reporting features
- [ ] Bulk resident registration import
- [ ] Email notification system
- [ ] SMS notifications
- [ ] Mobile app admin panel
- [ ] Advanced analytics with ML insights
- [ ] Offline mode support
- [ ] Dark mode UI

## Acknowledgments

- Flutter and Dart communities
- Firebase platform
- Supabase for backend infrastructure
- All contributors and testers

---

**Version**: 1.0.0  
**Last Updated**: April 2026  
**Status**: Active Development
