VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ThisOutlookSession"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = True
Public WithEvents GItems As Outlook.Items
Attribute GItems.VB_VarHelpID = -1
Private Sub Application_Startup()
    Set GItems = Outlook.Application.Session.GetDefaultFolder(olFolderInbox).Items
End Sub
Private Sub GItems_ItemAdd(ByVal Item As Object)
Dim xMtRequest As MeetingItem
Dim xAppointmentItem As AppointmentItem
Dim xMtResponse As MeetingItem
If Item.Class = olMeetingRequest Then
    Set xMtRequest = Item
    Set xAppointmentItem = xMtRequest.GetAssociatedAppointment(True)
    With xAppointmentItem
        .ReminderMinutesBeforeStart = 15
        .Save
    End With
    If InStr(xAppointmentItem.Categories, "PM Event") > 0 Then
        Set xMtResponse = xAppointmentItem.Respond(olMeetingAccepted)
        xMtResponse.Send
        xMtRequest.Delete
    End If
End If
End Sub

Private Sub GItems_ItemChange(ByVal Item As Object)

End Sub

Private Sub GItems_ItemRemove()

End Sub
