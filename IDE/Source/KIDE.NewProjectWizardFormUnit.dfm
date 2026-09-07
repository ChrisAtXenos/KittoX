inherited NewProjectWizardForm: TNewProjectWizardForm
  HelpContext = 120
  Caption = 'New KittoX Project'
  Constraints.MinHeight = 380
  Constraints.MinWidth = 480
  Position = poMainFormCenter
  OnCreate = FormCreate
  TextHeight = 13
  inherited PageControl: TPageControl
    ActivePage = AppTypeTabSheet
    object AppTypeTabSheet: TTabSheet
      Caption = 'DeploymentModesTabSheet'
      ImageIndex = 4
      DesignSize = (
        676
        316)
      object ProjectTemplatesPathButton: TSpeedButton
        Left = 638
        Top = 154
        Width = 23
        Height = 22
        Hint = 
          'Select the folder that contains the ProjectTemplates subfolders ' +
          '(Basic, Empty, ...)'
        Anchors = [akTop, akRight]
        Caption = '...'
        OnClick = ProjectTemplatesPathButtonClick
      end
      object DeploymentGroupBox: TGroupBox
        Left = 9
        Top = 0
        Width = 200
        Height = 118
        Caption = 'Deployment Modes'
        TabOrder = 0
        object DeployStandaloneCheckBox: TCheckBox
          Left = 11
          Top = 21
          Width = 180
          Height = 17
          Hint = 'Standalone server / Windows Service (.exe)'
          Caption = 'Windows App / Service (.exe)'
          Checked = True
          State = cbChecked
          TabOrder = 0
        end
        object DeployDesktopCheckBox: TCheckBox
          Left = 11
          Top = 44
          Width = 180
          Height = 17
          Hint = 'Embedded WebView2 desktop app (.exe)'
          Caption = 'Windows Desktop (.exe)'
          TabOrder = 1
        end
        object DeployISAPICheckBox: TCheckBox
          Left = 11
          Top = 67
          Width = 180
          Height = 17
          Hint = 'ISAPI module hosted under IIS (.dll)'
          Caption = 'ISAPI Module - IIS (.dll)'
          TabOrder = 2
        end
        object DeployApacheCheckBox: TCheckBox
          Left = 11
          Top = 90
          Width = 180
          Height = 17
          Hint = 'Apache 2.4 module (.dll)'
          Caption = 'Apache Module (.dll)'
          TabOrder = 3
        end
      end
      object ProjectTemplatesPathEdit: TLabeledEdit
        Left = 9
        Top = 154
        Width = 623
        Height = 21
        Hint = 
          'Folder containing the ProjectTemplates subfolders (Basic, Empty,' +
          ' ...)'
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 130
        EditLabel.Height = 13
        EditLabel.Caption = 'ProjectTemplates Directory'
        TabOrder = 1
        Text = ''
      end
    end
    object SelectTabSheet: TTabSheet
      Caption = 'SelectTabSheet'
      object TemplateSplitter: TSplitter
        Left = 373
        Top = 0
        Height = 316
        Align = alRight
        AutoSnap = False
        MinSize = 50
        ExplicitLeft = 157
        ExplicitHeight = 322
      end
      inline TemplateFrame: TProjectTemplateFrame
        Left = 0
        Top = 0
        Width = 373
        Height = 316
        Align = alClient
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        ExplicitWidth = 373
        ExplicitHeight = 316
        inherited ListView: TListView
          Width = 373
          Height = 316
          ExplicitWidth = 373
          ExplicitHeight = 316
        end
        inherited ImageList: TVirtualImageList
          Width = 64
          Height = 64
          Left = 48
          Top = 104
        end
        inherited ActionList: TActionList
          Left = 48
          Top = 40
        end
      end
      object TemplateInfoPanel: TPanel
        Left = 376
        Top = 0
        Width = 300
        Height = 316
        Align = alRight
        BevelOuter = bvNone
        TabOrder = 1
        object TemplateInfoRichEdit: TRichEdit
          Left = 0
          Top = 0
          Width = 300
          Height = 316
          Align = alClient
          Color = clWindow
          ParentFont = True
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
    end
    object OptionsTabSheet: TTabSheet
      Caption = 'OptionsTabSheet'
      ImageIndex = 1
      object DatabasesGroupBox: TGroupBox
        Left = 3
        Top = 0
        Width = 200
        Height = 121
        Caption = 'Database Adapters'
        TabOrder = 0
        object DBADOCheckBox: TCheckBox
          Left = 11
          Top = 90
          Width = 180
          Height = 17
          Caption = 'ADO (Deprecated)'
          TabOrder = 2
        end
        object DBDBXCheckBox: TCheckBox
          Left = 11
          Top = 67
          Width = 180
          Height = 17
          Caption = 'DBExpress (deprecated)'
          TabOrder = 1
        end
        object DBFDCheckBox: TCheckBox
          Left = 11
          Top = 21
          Width = 180
          Height = 17
          Caption = 'FireDac (connection pooling)'
          TabOrder = 0
        end
        object DBODACCheckBox: TCheckBox
          Left = 11
          Top = 43
          Width = 180
          Height = 17
          Caption = 'ODAC Oracle Data Access'
          TabOrder = 3
        end
      end
      object AccessControlGroupBox: TGroupBox
        Left = 221
        Top = 103
        Width = 200
        Height = 130
        Caption = 'Authentication/Authorization'
        TabOrder = 3
        object AuthenticationtypeLabel: TLabel
          Left = 20
          Top = 41
          Width = 95
          Height = 13
          Caption = 'Authentication type'
        end
        object AccessControltypeLabel: TLabel
          Left = 20
          Top = 83
          Width = 96
          Height = 13
          Caption = 'Access Control type'
        end
        object AuthComboBox: TComboBox
          Left = 20
          Top = 58
          Width = 160
          Height = 21
          TabOrder = 0
        end
        object UseJWTCheckBox: TCheckBox
          Left = 20
          Top = 16
          Width = 160
          Height = 17
          Hint = 'Wrap the auth storage in a signed JWT cookie (recommended)'
          Caption = 'Wrap in JWT envelope'
          Checked = True
          State = cbChecked
          TabOrder = 1
        end
        object ACComboBox: TComboBox
          Left = 20
          Top = 99
          Width = 160
          Height = 21
          TabOrder = 2
        end
      end
      object ServerGroupBox: TGroupBox
        Left = 221
        Top = 0
        Width = 200
        Height = 97
        Caption = 'Server'
        TabOrder = 1
        object PortLabel: TLabel
          Left = 64
          Top = 18
          Width = 20
          Height = 13
          Alignment = taRightJustify
          Caption = 'Port'
        end
        object ThreadPoolSizeLabel: TLabel
          Left = 9
          Top = 43
          Width = 73
          Height = 13
          Alignment = taRightJustify
          Caption = 'ThreadPoolSize'
        end
        object SessionTimeOutLabel: TLabel
          Left = 8
          Top = 67
          Width = 76
          Height = 13
          Alignment = taRightJustify
          Caption = 'SessionTimeOut'
        end
        object ServerPortEdit: TSpinEdit
          Left = 93
          Top = 15
          Width = 87
          Height = 22
          MaxValue = 0
          MinValue = 0
          TabOrder = 0
          Value = 8080
        end
        object ServerThreadPoolSizeEdit: TSpinEdit
          Left = 93
          Top = 39
          Width = 87
          Height = 22
          MaxValue = 0
          MinValue = 0
          TabOrder = 1
          Value = 20
        end
        object ServerSessionTimeOutEdit: TSpinEdit
          Left = 93
          Top = 64
          Width = 87
          Height = 22
          MaxValue = 0
          MinValue = 0
          TabOrder = 2
          Value = 10
        end
      end
      object LanguageGroupBox: TGroupBox
        Left = 3
        Top = 127
        Width = 200
        Height = 106
        Caption = 'Language && Encoding'
        TabOrder = 2
        object LanguageLabel: TLabel
          Left = 20
          Top = 18
          Width = 47
          Height = 13
          Alignment = taRightJustify
          Caption = 'Language'
        end
        object CharsetLabel: TLabel
          Left = 20
          Top = 60
          Width = 38
          Height = 13
          Alignment = taRightJustify
          Caption = 'Charset'
        end
        object LanguageIdComboBox: TComboBox
          Left = 20
          Top = 35
          Width = 160
          Height = 21
          ItemIndex = 0
          TabOrder = 0
          Items.Strings = (
            'en'
            'it')
        end
        object CharsetComboBox: TComboBox
          Left = 20
          Top = 75
          Width = 160
          Height = 21
          ItemIndex = 0
          TabOrder = 1
          Items.Strings = (
            'utf-8'
            'iso-8859-1')
        end
      end
    end
    object GoTabSheet: TTabSheet
      Caption = 'GoTabSheet'
      ImageIndex = 2
      DesignSize = (
        676
        316)
      object ProjectPathButton: TSpeedButton
        Left = 643
        Top = 32
        Width = 23
        Height = 22
        Hint = 'Select an empty directory for the new project'
        Anchors = [akTop, akRight]
        Caption = '...'
        OnClick = ProjectPathButtonClick
      end
      object ProjectPathEdit: TLabeledEdit
        Left = 24
        Top = 32
        Width = 613
        Height = 21
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 105
        EditLabel.Height = 13
        EditLabel.Caption = 'New Project Directory'
        TabOrder = 0
        Text = ''
        OnExit = ProjectPathEditExit
      end
      object ProjectNameEdit: TLabeledEdit
        Left = 24
        Top = 80
        Width = 137
        Height = 21
        EditLabel.Width = 64
        EditLabel.Height = 13
        EditLabel.Caption = 'Project Name'
        TabOrder = 1
        Text = ''
        OnChange = ProjectNameEditChange
      end
      object AppTitleEdit: TLabeledEdit
        Left = 167
        Top = 80
        Width = 470
        Height = 21
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 75
        EditLabel.Height = 13
        EditLabel.Caption = 'Application Title'
        TabOrder = 2
        Text = ''
      end
    end
    object DoneTabSheet: TTabSheet
      Caption = 'DoneTabSheet'
      ImageIndex = 3
      object ProjectCreatedRichEdit: TRichEdit
        Left = 0
        Top = 0
        Width = 676
        Height = 316
        Align = alClient
        Color = clWindow
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
  end
end
