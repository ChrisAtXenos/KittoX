inherited ProjectTemplateFrame: TProjectTemplateFrame
  object ListView: TListView
    Left = 0
    Top = 0
    Width = 320
    Height = 240
    Align = alClient
    Columns = <>
    HideSelection = False
    IconOptions.AutoArrange = True
    LargeImages = ImageList
    TabOrder = 0
    OnDblClick = ListViewDblClick
    OnSelectItem = ListViewSelectItem
  end
  object ImageList: TVirtualImageList
    Images = <
      item
        CollectionIndex = 168
        CollectionName = 'Kitto'
        Name = 'Kitto'
      end>
    ImageCollection = MainDataModule.ImageCollection
    Width = 24
    Height = 24
    Left = 168
    Top = 80
  end
  object ActionList: TActionList
    Left = 112
    Top = 96
  end
end
