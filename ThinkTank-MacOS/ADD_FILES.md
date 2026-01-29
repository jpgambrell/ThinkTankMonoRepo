# Add New Files to Xcode Project

The following new files have been created but need to be added to the Xcode project:

## AWS Services
- `ThinkTank/Services/AWS/AWSConfig.swift`
- `ThinkTank/Services/AWS/CognitoAuthService.swift`
- `ThinkTank/Services/AWS/APIClient.swift`

## Authentication Views
- `ThinkTank/Views/Auth/LoginView.swift`
- `ThinkTank/Views/Auth/RegistrationView.swift`

## How to Add Files to Xcode

### Option 1: Using Xcode GUI (Recommended)
1. Open `ThinkTank.xcodeproj` in Xcode
2. Right-click on the `ThinkTank` folder in the project navigator
3. Select "Add Files to 'ThinkTank'..."
4. Navigate to and select:
   - The `Services/AWS` folder
   - The `Views/Auth` folder
5. Make sure "Copy items if needed" is **unchecked**
6. Make sure "Create groups" is selected
7. Make sure the "ThinkTank" target is checked
8. Click "Add"
9. Clean build folder (Cmd+Shift+K)
10. Build (Cmd+B)

### Option 2: Using Terminal (if files don't appear)
If Xcode doesn't show the new folders, close Xcode and run:

```bash
cd /Users/john.gambrell/Projects/ThinkTank/ThinkTank-MacOS
open ThinkTank.xcodeproj
```

Then follow Option 1 above.

## What These Files Do

### AWS Configuration
- `AWSConfig.swift` - Contains all AWS endpoint URLs and configuration
- `CognitoAuthService.swift` - Handles user authentication (sign up, sign in, sign out)
- `APIClient.swift` - Real API client that replaces the mock backend

### Authentication UI
- `LoginView.swift` - Login screen with email/password
- `RegistrationView.swift` - Registration screen with validation

## Next Steps After Adding Files

1. Build the project (Cmd+B)
2. Run the app (Cmd+R)
3. You should see the login screen
4. Create an account or sign in
5. Start chatting with real AI models!
