#ifndef AppVersion
#define AppVersion "0.0.0"
#endif

#ifndef SourceDir
#define SourceDir "..\dist"
#endif

#ifndef OutputDir
#define OutputDir "..\dist-installer"
#endif

#ifndef InstallerDir
#define InstallerDir "."
#endif

#ifndef InstallerSolidCompression
#define InstallerSolidCompression "yes"
#endif

[Setup]
AppId={{F94D0E6D-2B2A-41E0-A821-1E489E24F9E5}
AppName=MCNexus
AppVersion={#AppVersion}
AppVerName=MCNexus v{#AppVersion}
AppPublisher=Magno Ciqueira
AppPublisherURL=https://mcnexus.app/
AppSupportURL=https://github.com/ciqueira/MCNexus/issues
AppUpdatesURL=https://github.com/ciqueira/MCNexus/releases
AppContact=https://github.com/ciqueira/MCNexus/issues
AppReadmeFile=https://github.com/ciqueira/MCNexus
AppComments=Installs MCNexus, a Windows desktop manager for MC OFX plugin licenses and installation.
DefaultDirName={autopf}\MCNexus
DefaultGroupName=MCNexus
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
InfoBeforeFile={#InstallerDir}\INSTALLATION-NOTES.txt
OutputDir={#OutputDir}
OutputBaseFilename=MCNexus-Setup-v{#AppVersion}
Compression=lzma2
SolidCompression={#InstallerSolidCompression}
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName=MCNexus
UninstallDisplayIcon={app}\MCNexus.exe
SetupIconFile={#InstallerDir}\..\Assets\AppIcon.ico
WizardImageFile={#InstallerDir}\Images\wizard_side.png
WizardSmallImageFile={#InstallerDir}\Images\wizard_top.png
WizardImageBackColor=$1E1E1E
; WizardSideColor=$1E1E1E ; Commented out because unsupported by current Inno Setup version
VersionInfoCompany=Magno Ciqueira
VersionInfoDescription=MCNexus Setup
VersionInfoProductName=MCNexus
VersionInfoProductVersion={#AppVersion}
CloseApplications=yes
CloseApplicationsFilter=MCNexus.exe
RestartApplications=no
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Copy light/dark icons into the application folder using the actual build output paths
Source: "{#SourceDir}\Assets\AppIconLight.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\Assets\AppIconDark.ico";  DestDir: "{app}"; Flags: ignoreversion

[Icons]
; The installer selects the shortcut icon from the Windows app theme.
Name: "{autoprograms}\MCNexus"; Filename: "{app}\MCNexus.exe"; IconFilename: "{code:GetShortcutIconPath}"; AppUserModelID: "MagnoCiqueira.MCNexus"; WorkingDir: "{app}"
Name: "{autodesktop}\MCNexus"; Filename: "{app}\MCNexus.exe"; IconFilename: "{code:GetShortcutIconPath}"; AppUserModelID: "MagnoCiqueira.MCNexus"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{{F94D0E6D-2B2A-41E0-A821-1E489E24F9E5}_is1"; ValueType: string; ValueName: "PrivacyPolicyUrl"; ValueData: "https://github.com/ciqueira/MCNexus/blob/main/PRIVACY.md"; Flags: uninsdeletevalue

[Run]
; Launch with the original non-elevated user token so MCNexus exercises its
; normal asInvoker -> UAC relaunch flow after Setup completes.
Filename: "{autoprograms}\MCNexus.lnk"; Description: "Launch MCNexus"; Flags: nowait postinstall skipifsilent unchecked shellexec runasoriginaluser

[Code]
const
  InstallModeNew = 0;
  InstallModeUpdate = 1;
  InstallModeRepair = 2;
  InstallModeDowngrade = 3;
  UninstallRegistryKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{F94D0E6D-2B2A-41E0-A821-1E489E24F9E5}_is1';

var
  ExistingInstallPage: TOutputMsgWizardPage;
  PrivacyPage: TWizardPage;
  PrivacySummaryLabel: TNewStaticText;
  PrivacyLinkLabel: TNewStaticText;
  ExistingInstallMode: Integer;
  InstalledVersion: String;
  InstalledDirectory: String;
  PreviousNextButtonCaption: String;
  HasExistingInstallPage: Boolean;
  OperationButtonCaptionApplied: Boolean;

procedure PrivacyLinkClick(Sender: TObject);
var
  ErrorCode: Integer;
begin
  if not ShellExec(
    'open',
    'https://mcnexus.app/privacy/',
    '',
    '',
    SW_SHOWNORMAL,
    ewNoWait,
    ErrorCode
  ) then
  begin
    MsgBox(
      'Could not open the Privacy Policy in your browser.' + #13#10#13#10 +
      'https://mcnexus.app/privacy/',
      mbError,
      MB_OK
    );
  end;
end;

procedure CreatePrivacyPage();
begin
  PrivacyPage := CreateCustomPage(
    wpInfoBefore,
    'Privacy',
    'Review how MCNexus handles licensing and device information.'
  );

  PrivacySummaryLabel := TNewStaticText.Create(PrivacyPage);
  PrivacySummaryLabel.Parent := PrivacyPage.Surface;
  PrivacySummaryLabel.Left := 0;
  PrivacySummaryLabel.Top := 8;
  PrivacySummaryLabel.Width := PrivacyPage.SurfaceWidth;
  PrivacySummaryLabel.Height := 92;
  PrivacySummaryLabel.AutoSize := False;
  PrivacySummaryLabel.WordWrap := True;
  PrivacySummaryLabel.Caption :=
    'MCNexus processes information required for licensing, product delivery, security, updates, and support.' + #13#10#13#10 +
    'Limited technical data may be processed for security, reliability, diagnostics, and service improvement, as described in the Privacy Policy.' + #13#10#13#10 +
    'The complete Privacy Policy is available in Portuguese and English.';

  PrivacyLinkLabel := TNewStaticText.Create(PrivacyPage);
  PrivacyLinkLabel.Parent := PrivacyPage.Surface;
  PrivacyLinkLabel.Left := 0;
  PrivacyLinkLabel.Top := PrivacySummaryLabel.Top + PrivacySummaryLabel.Height + 16;
  PrivacyLinkLabel.AutoSize := True;
  PrivacyLinkLabel.Caption := 'Open the MCNexus Privacy Policy';
  PrivacyLinkLabel.Font.Color := clBlue;
  PrivacyLinkLabel.Font.Style := [fsUnderline];
  PrivacyLinkLabel.Cursor := crHand;
  PrivacyLinkLabel.OnClick := @PrivacyLinkClick;
end;

function ReadInstalledValue(const ValueName: String; var Value: String): Boolean;
begin
  Result := False;

  if IsWin64 then
  begin
    Result := RegQueryStringValue(HKLM64, UninstallRegistryKey, ValueName, Value);
  end;

  if not Result then
  begin
    Result := RegQueryStringValue(HKLM32, UninstallRegistryKey, ValueName, Value);
  end;

  if not Result then
  begin
    Result := RegQueryStringValue(HKCU, UninstallRegistryKey, ValueName, Value);
  end;
end;

function ReadNextVersionPart(var Version: String): Integer;
var
  SeparatorPosition: Integer;
  Segment: String;
  NumericSegment: String;
  CharacterIndex: Integer;
begin
  SeparatorPosition := Pos('.', Version);
  if SeparatorPosition > 0 then
  begin
    Segment := Copy(Version, 1, SeparatorPosition - 1);
    Delete(Version, 1, SeparatorPosition);
  end
  else
  begin
    Segment := Version;
    Version := '';
  end;

  NumericSegment := '';
  for CharacterIndex := 1 to Length(Segment) do
  begin
    if (Segment[CharacterIndex] >= '0') and (Segment[CharacterIndex] <= '9') then
    begin
      NumericSegment := NumericSegment + Segment[CharacterIndex];
    end
    else
    begin
      Break;
    end;
  end;

  Result := StrToIntDef(NumericSegment, 0);
end;

function CompareAppVersions(LeftVersion, RightVersion: String): Integer;
var
  PartIndex: Integer;
  LeftPart: Integer;
  RightPart: Integer;
begin
  LeftVersion := Trim(LeftVersion);
  RightVersion := Trim(RightVersion);

  if (Length(LeftVersion) > 0) and
     ((LeftVersion[1] = 'v') or (LeftVersion[1] = 'V')) then
  begin
    Delete(LeftVersion, 1, 1);
  end;

  if (Length(RightVersion) > 0) and
     ((RightVersion[1] = 'v') or (RightVersion[1] = 'V')) then
  begin
    Delete(RightVersion, 1, 1);
  end;

  Result := 0;
  for PartIndex := 1 to 8 do
  begin
    LeftPart := ReadNextVersionPart(LeftVersion);
    RightPart := ReadNextVersionPart(RightVersion);

    if LeftPart < RightPart then
    begin
      Result := -1;
      Exit;
    end;

    if LeftPart > RightPart then
    begin
      Result := 1;
      Exit;
    end;
  end;
end;

function ExistingInstallMessage(const NewVersion: String): String;
var
  OperationText: String;
begin
  case ExistingInstallMode of
    InstallModeUpdate:
      OperationText :=
        'An earlier version of MCNexus was detected.' + #13#10#13#10 +
        'MCNexus ' + InstalledVersion + ' will be updated to ' + NewVersion + '.';
    InstallModeRepair:
      OperationText :=
        'MCNexus ' + InstalledVersion + ' is already installed.' + #13#10#13#10 +
        'Setup will repair and reinstall the application files.';
    InstallModeDowngrade:
      OperationText :=
        'A newer version of MCNexus is installed.' + #13#10#13#10 +
        'Continuing will replace MCNexus ' + InstalledVersion +
        ' with the older version ' + NewVersion + '.';
  end;

  Result :=
    OperationText + #13#10#13#10 +
    'The application will be closed while Setup replaces its files.' + #13#10#13#10 +
    'Saved licenses, protected credentials, session data, settings, SDK cache, and installed OFX plugins will be preserved.';

  if InstalledDirectory <> '' then
  begin
    Result := Result + #13#10#13#10 + 'Installation folder:' + #13#10 + InstalledDirectory;
  end;
end;

procedure InitializeWizard;
var
  NewVersion: String;
  VersionComparison: Integer;
  PageCaption: String;
  PageDescription: String;
begin
  CreatePrivacyPage();

  ExistingInstallMode := InstallModeNew;
  InstalledVersion := '';
  InstalledDirectory := '';
  HasExistingInstallPage := False;
  OperationButtonCaptionApplied := False;

  if not ReadInstalledValue('DisplayVersion', InstalledVersion) then
  begin
    Exit;
  end;

  ReadInstalledValue('InstallLocation', InstalledDirectory);
  NewVersion := '{#AppVersion}';
  VersionComparison := CompareAppVersions(InstalledVersion, NewVersion);
  Log(
    'Existing MCNexus installation detected. Installed version: ' +
    InstalledVersion + '; setup version: ' + NewVersion +
    '; directory: ' + InstalledDirectory
  );

  if VersionComparison < 0 then
  begin
    ExistingInstallMode := InstallModeUpdate;
    PageCaption := 'Update MCNexus';
    PageDescription := 'An existing installation will be updated.';
  end
  else if VersionComparison = 0 then
  begin
    ExistingInstallMode := InstallModeRepair;
    PageCaption := 'Repair MCNexus';
    PageDescription := 'The installed version will be repaired and reinstalled.';
  end
  else
  begin
    ExistingInstallMode := InstallModeDowngrade;
    PageCaption := 'Install an older version';
    PageDescription := 'Review the downgrade before continuing.';
  end;

  ExistingInstallPage := CreateOutputMsgPage(
    wpWelcome,
    PageCaption,
    PageDescription,
    ExistingInstallMessage(NewVersion)
  );
  HasExistingInstallPage := True;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if not HasExistingInstallPage then
  begin
    Exit;
  end;

  if (CurPageID = ExistingInstallPage.ID) and
     not OperationButtonCaptionApplied then
  begin
    PreviousNextButtonCaption := WizardForm.NextButton.Caption;
    OperationButtonCaptionApplied := True;

    case ExistingInstallMode of
      InstallModeUpdate:
        WizardForm.NextButton.Caption := 'Update';
      InstallModeRepair:
        WizardForm.NextButton.Caption := 'Reinstall';
      InstallModeDowngrade:
        WizardForm.NextButton.Caption := 'Continue';
    end;
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if not HasExistingInstallPage then
  begin
    Exit;
  end;

  if CurPageID <> ExistingInstallPage.ID then
  begin
    Exit;
  end;

  if ExistingInstallMode = InstallModeDowngrade then
  begin
    Result :=
      MsgBox(
        'A newer version of MCNexus is currently installed.' + #13#10#13#10 +
        'Do you want to replace version ' + InstalledVersion +
        ' with version {#AppVersion}?',
        mbConfirmation,
        MB_YESNO or MB_DEFBUTTON2
      ) = IDYES;
  end;

  if Result then
  begin
    WizardForm.NextButton.Caption := PreviousNextButtonCaption;
    OperationButtonCaptionApplied := False;
  end;
end;

function BackButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if not HasExistingInstallPage then
  begin
    Exit;
  end;

  if CurPageID = ExistingInstallPage.ID then
  begin
    WizardForm.NextButton.Caption := PreviousNextButtonCaption;
    OperationButtonCaptionApplied := False;
  end;
end;

function GetShortcutIconPath(Param: String): String;
var
  AppsUseLightTheme: Cardinal;
begin
  if RegQueryDWordValue(
    HKCU,
    'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
    'AppsUseLightTheme',
    AppsUseLightTheme
  ) and (AppsUseLightTheme <> 0) then
  begin
    Result := ExpandConstant('{app}\AppIconLight.ico');
  end
  else
  begin
    Result := ExpandConstant('{app}\AppIconDark.ico');
  end;
end;

procedure CloseRunningApp();
var
  ResultCode: Integer;
begin
  Exec(
    ExpandConstant('{sys}\taskkill.exe'),
    '/IM "MCNexus.exe" /T',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
  Sleep(1000);
  Exec(
    ExpandConstant('{sys}\taskkill.exe'),
    '/IM "MCNexus.exe" /T /F',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
end;

procedure RemoveLocalAppData();
var
  TempDirectory: String;
begin
  DelTree(ExpandConstant('{userappdata}\MCAppsTools'), True, True, True);
  DelTree(ExpandConstant('{userappdata}\MCAppsTools-Staging'), True, True, True);
  DelTree(ExpandConstant('{userappdata}\MCAppsTools-Local'), True, True, True);
  DelTree(ExpandConstant('{commonappdata}\MCAppsTools'), True, True, True);

  TempDirectory := GetEnv('TEMP');
  if TempDirectory <> '' then
  begin
    DelTree(AddBackslash(TempDirectory) + 'MCAppsTools', True, True, True);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  RemoveLocalData: Integer;
begin
  if CurUninstallStep <> usUninstall then
  begin
    Exit;
  end;

  CloseRunningApp();

  RemoveLocalData := MsgBox(
    'Do you also want to remove local MCNexus license data, settings, temporary downloads, session files, and SDK cache?' + #13#10#13#10 +
    'Choose No to keep this data for a future reinstall or update.',
    mbConfirmation,
    MB_YESNO or MB_DEFBUTTON2
  );

  if RemoveLocalData = IDYES then
  begin
    RemoveLocalAppData();
  end;
end;
