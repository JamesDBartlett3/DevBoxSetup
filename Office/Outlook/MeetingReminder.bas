Attribute VB_Name = "MeetingReminder"

Sub SetReminderMeetings(oRequest As MeetingItem)

Dim oAppt As AppointmentItem
Set oAppt = oRequest.GetAssociatedAppointment(True)

' change the reminder time

If (oAppt.ReminderSet = False Or oAppt.ReminderMinutesBeforeStart <> 15) And Not InStr(oAppt.Subject, "Canceled:") Then
    oAppt.ReminderMinutesBeforeStart = 15
    oAppt.ReminderSet = True
    oAppt.Save
End If

End Sub
