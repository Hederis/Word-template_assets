Attribute VB_Name = "PrintStyles"
Option Explicit
Option Base 1
Sub PrintStyles()
    ' Prints current styles names to the left of each paragraph
    
    ' ===== DEPENDENCIES ==========================================================
    ' Requires module AttachTemplateMacro
    ' Before you run this, create a text box with the listed settings below, then select the
    ' text box and go to Insert > Text Box > Save Selection to Text Box Gallery (Word 2013). In the
    ' Create New Building Block dialog that opens, name the Building Block "StyleNames1" and
    ' give it the category "Macmillan." Be sure to save it in the template at the path below.
    
    ' TEXT BOX SETTINGS:
    ' Layout > Position > Horizontal: Absolute position 0.13" to the right of Left Margin
    ' Layout > Position > Vertical: Absolute position 0" below paragraph
    ' Layout > Position > Lock Anchor = True
    ' Layout > Position > Allow overlap = true
    ' Layout > Text wrapping > Wrapping style = Square
    ' Layout > Text wrapping > Text wrap = right only
    ' Layout > Distance from text = 0" (each side)
    ' Layout > Size > Height: Absolute 0.4"
    ' Layout > Size > Width: Absolute 1.35
    ' Format > Shape Styles > Shape Outline > No outline
    
    ' ===== LIMITATIONS ==========================================================
    ' "Normal" can't be in-use as a style in the document
    ' If total margin size (left + right) is < 2 " paragraphs will reflow
    ' Doesn't work for endnotes/footnotes (can't add a drawing object to EN/FNs)
    
    ' ====== TO DO ======
    ' add progress bar?
    
    ''-----------------Check if doc is saved/protected---------------
    If CheckSave = True Then
        Exit Function
    End If
    
    Application.ScreenUpdating = False
    
    ' ===== Copy and Paste into a new doc ===================
    ' Paste below throws an alert that too many styles are being copied, so turn off alerts
    ' Also make sure paste settings maintain styles
    Dim lngOpt As Long
    Dim lngPasteStyled As Long
    Dim lngPasteFormat As Long
    
    With Application
    ' record current settings to reset in Cleanup
        lngOpt = .DisplayAlerts
        lngPasteStyled = .Options.PasteFormatBetweenStyledDocuments
        lngPasteFormat = .Options.PasteFormatBetweenDocuments
        .DisplayAlerts = wdAlertsNone
        .Options.PasteFormatBetweenStyledDocuments = wdKeepSourceFormatting
        .Options.PasteFormatBetweenDocuments = wdKeepSourceFormatting
    End With
    
    ' ===== Create new version of this document to manipulate ============
    ' Copy the text of the document into a new document, so we don't screw up the original
    ' Needs to have the BoundMS template attached before copying so the styles match
    ' the new document later, or won't copy any styles
    Dim currentTemplate As String
    Dim currentDoc As Document
    Set currentDoc = ActiveDocument
    ' Record current template
    currentTemplate = currentDoc.AttachedTemplate
    
    ' Attach BoundMS template to original doc, then copy contents
    Call AttachTemplateMacro.zz_AttachBoundMSTemplate
    currentDoc.StoryRanges(wdMainTextStory).Copy
    
    Dim tempDoc As Document
    ' Create a new document
    Set tempDoc = Documents.Add '(Visible:=False) ' Can I set visibility to False here on Mac?
    ' Add Macmillan styles with no color guides (because if we don't add them,
    ' we get an error that there are too many styles to paste and it just pastes
    ' all with Normal style)
    tempDoc.Activate
    Call AttachTemplateMacro.zz_AttachBoundMSTemplate
    tempDoc.Content.PasteAndFormat wdFormatOriginalFormatting
        
    ' ===== Set margins =================
    ' if possible, we want the total margin size to stay the same
    ' so that the paragraphs don't reflow
    ' note margins are in points, 72 pts = 1 inch
    Dim currentLeft As Long
    Dim currentRight As Long
    Dim currentTotal As Long
    
    With tempDoc.PageSetup
        currentLeft = .LeftMargin
        currentRight = .RightMargin
        currentTotal = currentLeft + currentRight
        .LeftMargin = 108   ' 1.5 inches
            If currentTotal >= 144 Then     ' 2 inches
                .RightMargin = currentTotal - 108   ' 1.5 inches
            Else
                .RightMargin = 36   '.5 inches (minimum right margin)
            End If
    End With
    
    ' ==== Change Normal style formatting (since it will define the text boxes) =====
    ' But save settings first and then change back -- are these settings sticky?
    Dim currentSize As Long
    Dim currentName As String
    Dim currentSpace As Long
    
    With tempDoc.Styles("Normal")
        currentSize = .Font.Size
        currentName = .Font.Name
        currentSpace = .ParagraphFormat.SpaceAfter
        .Font.Size = 7
        .Font.Name = "Calibri"
        .ParagraphFormat.SpaceAfter = 0
    End With
    
    Dim strPath As String
    Dim objTemplate As Template
    Dim objBB As BuildingBlock
    Dim strStyle As String
    Dim lngTextBoxes As Long
    Dim a As Long
    Dim b As Long
    
    ' This is the template where the building block is saved
    strPath = Environ("APPDATA") & "\Microsoft\Word\STARTUP\MacmillanGT.dotm"
    If IsItThere(strPath) = True Then
        Set objTemplate = Templates(strPath)
    Else
        MsgBox "I can't find the Macmillan template, sorry."
        GoTo Cleanup
    End If
    
    ' Access the building block through the type and category
    ' NOTE the text box building block has to already be created in the template.
    Set objBB = objTemplate.BuildingBlockTypes(wdTypeTextBox).Categories("Macmillan").BuildingBlocks("StyleNames1")
    
    ' Count the number of current text boxes etc., because the index number of the new ones
    ' will be offset by that amount
    lngTextBoxes = tempDoc.Shapes.Count
    
    For a = 1 To tempDoc.Paragraphs.Count
    
        tempDoc.Paragraphs(a).Range.Select
        strStyle = Selection.Style
        Selection.Collapse Direction:=wdCollapseStart
        objBB.Insert Where:=Selection.Range
        tempDoc.Shapes(a + lngTextBoxes).TextFrame.TextRange.Text = strStyle
    
    Next a

    ' Now open the print dialog so user can print the document.
    Dialogs(wdDialogFilePrint).Show
    
    ' reset Normal style because I'm not sure if it's sticky or not
    With tempDoc.Styles("Normal")
        .Font.Size = currentSize
        .Font.Name = currentName
        .ParagraphFormat.SpaceAfter = currentSpace
    End With
    
Cleanup:
    ' Close newly created doc w/o saving
    Dim tempDocPath As String
    tempDocPath = tempDoc.Path

    If IsItThere(tempDocPath) = True Then
        tempDoc.Close wdDoNotSaveChanges
    End If
    
    ' Return original document to original template
    currentDoc.Activate
    Call AttachTemplateMacro.AttachMe(TemplateName:=currentTemplate)
    
    ' Reset settings to original
    With Application
        .DisplayAlerts = lngOpt
        .Options.PasteFormatBetweenStyledDocuments = lngPasteStyled
        .Options.PasteFormatBetweenDocuments = lngPasteFormat
        .ScreenUpdating = True
        .ScreenRefresh
    End With
End Sub


