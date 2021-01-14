//  ContentView.swift
//  MyVIAlarm
//
//  Created by Joel Schow

import SwiftUI
import CoreData
import AVFoundation

enum page {
    case mainPage
    case alarmPage
}

enum editAlarmState {
    case editHour
    case editMinute
    case editAMPM
    case confirm
    case off
}

struct ContentView: View {
    
    @StateObject var delegate = NotificationDelegate()
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Alarm.entity(), sortDescriptors: []) var alarms : FetchedResults<Alarm>
    @State private var myAlarm : Alarm?
    @State private var currentPage : page = .mainPage
    @State private var currentEditAlarmState : editAlarmState = .off
    @State private var backgroundColor = CGColor(red: 84/225, green: 131/225, blue: 151/225, alpha: 1)
    @State private var darkBackground = CGColor(red: 22/225, green: 22/225, blue: 24/225, alpha: 1)
    @State private var lightBackground = CGColor(red: 129/225, green: 129/225, blue: 129/225, alpha: 1)
    @State private var darkText = CGColor(red: 0/225, green: 0/225, blue: 0/225, alpha: 1)
    @State private var editHourValue : Int?
    @State private var editMinuteValue : Int?
    @State private var editAMPMValue : Int? //1 for AM, 2 for PM
    @State private var syn = AVSpeechSynthesizer()
    
    var body: some View {
        ZStack{
            
            Color(.white)
                .onAppear(perform: {
                    print("MyVIAlarm has started")
                    UNUserNotificationCenter.current().delegate = delegate
                    getAppData()
                    getPermissions()
                    correctCurrentAlarmDate()
                    dictateInitialInstructions()
                })
                .gesture(
                    DragGesture(minimumDistance: 3.0, coordinateSpace: .local)
                    .onChanged{ value in
                    }
                    .onEnded { value in
                        if currentPage == .mainPage {
                            if value.translation.width <  -(UIScreen.screenWidth / 2) && value.translation.height > -50 && value.translation.height < 50 {
                                print("left swipe")
                                print("Entering alarmPage")
                                handleStartAlarmEditing()
                            }
                            else if value.translation.height < 0 && value.translation.width < 100 && value.translation.width > -100 {
                                print("up swipe")
                                handleAlarmToggle()
                                dictateAlarmToggleStatus()
                            }
                            else if value.translation.height > 0 && value.translation.width < 100 && value.translation.width > -100 {
                                print("down swipe")
                                createDemoAlarm()
                            }
                            else {
                                print("non-conclusive swipe")
                            }
                        } else {
                            if value.translation.width > (UIScreen.screenWidth / 2) && value.translation.height > -50 && value.translation.height < 50 {
                                print("right swipe")
                                print("Entering mainPage")
                                currentPage = .mainPage
                                dictateCancelEnteringMainPage()
                            }
                            else if value.translation.height < 0 && value.translation.width < 100 && value.translation.width > -100 {
                                print("up swipe")
                                if currentEditAlarmState == .editHour {
                                    if editHourValue! >= 12 {
                                        editHourValue! = 1
                                        
                                    } else {
                                        editHourValue! += 1
                                    }
                                    dictateEditHourUpdate()
                                } else if currentEditAlarmState == .editMinute {
                                    if editMinuteValue! >= 45 {
                                        editMinuteValue! = 00
                                    } else {
                                        editMinuteValue! += 15
                                    }
                                    dictateEditMinuteUpdate()
                                } else if currentEditAlarmState == .editAMPM {
                                    editAMPMValue = 1
                                    dictateEditAMPMUpdate()
                                }
                            }
                            else if value.translation.height > 0 && value.translation.width < 100 && value.translation.width > -100 {
                                print("down swipe")
                                if currentEditAlarmState == .editHour {
                                    if editHourValue! <= 1 {
                                        editHourValue! = 12
                                    } else {
                                        editHourValue! -= 1
                                    }
                                    dictateEditHourUpdate()
                                } else if currentEditAlarmState == .editMinute {
                                    if editMinuteValue! <= 00 {
                                        editMinuteValue! = 45
                                    } else {
                                        editMinuteValue! -= 15
                                    }
                                    dictateEditMinuteUpdate()
                                } else if currentEditAlarmState == .editAMPM {
                                    editAMPMValue = 2
                                    dictateEditAMPMUpdate()
                                }
                            }
                            else {
                                print("non-conclusive swipe")
                            }
                        }
                    }
                )
                .onTapGesture(count: 2, perform: {
                    print("double tap")
                    if currentPage == .mainPage {
                        dictateTimeAndAlarmDetails()
                    } else {
                        switch currentEditAlarmState {
                        case .editHour:
                            print("confirmed in edit alarm state for edit hour with value \(editHourValue!)")
                            currentEditAlarmState = .editMinute
                            dictateEditMinuteInstructions()
                        case .editMinute:
                            print("confirmed double tap in edit alarm state for edit minute with value \(editMinuteValue!)")
                            currentEditAlarmState = .editAMPM
                            dictateEditAMPMInstructions()
                        case .editAMPM:
                            print("confirmed double tap in edit alarm state for edit AMPM with value \(editAMPMValue!)")
                            currentEditAlarmState = .confirm
                            dictateEditAlarmConfirmInstructions()
                        case .confirm:
                            print("FINAL ALARM CONFIRMED")
                            saveAlarmValues()
                            dictateEditAlarmConfirmUpdate()
                            turnAlarmOn()
                            currentPage = .mainPage
                            currentEditAlarmState = .off
                        default:
                            print("double tap in edit alarm state for default")
                        }
                    }
                })
                .onTapGesture(count: 1, perform: {
                    print("single tap")
                    if currentPage == .mainPage {
                        dictateMainPageInstructions()
                    } else {
                        switch currentEditAlarmState {
                        case .editHour:
                            dictateEditHourInstructionsTap()
                        case .editMinute:
                            dictateEditMinuteInstructionsTap()
                        case .editAMPM:
                            dictateEditAMPMInstructionsTap()
                        case .confirm:
                            dictateEditConfirmInstructionsTap()
                        default:
                            print("deault entered in single tap gesture")
                        }
                    }
                })
            VStack {
                Text("MyVIAlarm")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("Joel Schow")
                    .font(.system(size: 16, weight: .light, design: .rounded))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(#colorLiteral(red: 0.8135031795, green: 0.8715417949, blue: 0.9930160315, alpha: 1)))
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
        }
        
    }
    
    //Helper Functions
    func getAppData(){
        print("Begin getting app data")
        if alarms.count == 0 {
            print("Making new alarm data")
            let newAlarm = Alarm(context: self.moc)
            let date = Date()
            
            let newDateComponents = DateComponents(
                calendar: Calendar.current,
                timeZone: TimeZone.current,
                era: Calendar.current.component(.era, from: date),
                year: Calendar.current.component(.year, from: date),
                month: Calendar.current.component(.month, from: date),
                day: Calendar.current.component(.day, from: date),
                hour: 00,
                minute: 00,
                second: 00,
                nanosecond: 00,
                weekday: Calendar.current.component(.weekday, from: date),
                weekdayOrdinal: Calendar.current.component(.weekdayOrdinal, from: date),
                quarter: Calendar.current.component(.quarter, from: date),
                weekOfMonth: Calendar.current.component(.weekOfMonth, from: date),
                weekOfYear: Calendar.current.component(.weekOfYear, from: date),
                yearForWeekOfYear: Calendar.current.component(.yearForWeekOfYear, from: date))
            
            let newAlarmTime = Calendar.current.date(from: newDateComponents) ?? Date()
            let newAlarmStatus = false
            
            print("alarm description: \(getDateText(date: newAlarmTime))")
            
            newAlarm.time = newAlarmTime
            newAlarm.status = newAlarmStatus
            
            try? self.moc.save()
        }
        
        print("Loading existing alarm data")
        myAlarm = alarms[0]
        
        getEditValues()
    }
    
    func getEditValues(){
        let tempHourValue = Calendar.current.component(.hour, from: myAlarm?.time ?? Date())
        if tempHourValue >= 12 {
            editAMPMValue = 2
            if tempHourValue == 12 {
                editHourValue = 12
            } else {
                editHourValue = tempHourValue - 12
            }
        } else {
            editAMPMValue = 1
            if tempHourValue == 00 {
                editHourValue = 12
            } else {
                editHourValue = tempHourValue
            }
        }
        editMinuteValue = Calendar.current.component(.minute, from: myAlarm?.time ?? Date())
    }
    
    func handleStartAlarmEditing(){
        currentPage = .alarmPage
        currentEditAlarmState = .editHour
        getEditValues()
        dictateEditHourInstructions()
    }
    
    func handleAlarmToggle(){
        if myAlarm!.status == true {
            turnAlarmOff()
        } else {
            turnAlarmOn()
        }
    }
    
    func turnAlarmOn(){
        correctCurrentAlarmDate()
        myAlarm!.status = true
        try? self.moc.save()
        deleteAlarmNotification()
        createAlarmNotification()
    }
    
    func turnAlarmOff(){
        myAlarm!.status = false
        try? self.moc.save()
        
        deleteAlarmNotification()
    }
    
    func saveAlarmValues(){
        print("Alarm values before save are \(getDateText(date: myAlarm!.time!))")
        print("Saving Alarm values of Hour : \(editHourValue!), Minute : \(editMinuteValue!), AMPM : \(editAMPMValue!)")
        myAlarm!.time = Date()
        myAlarm!.time = Calendar.current.date(bySetting: .hour, value: convertToMillitaryTime(hourValue: editHourValue!, AmPm: editAMPMValue!), of: myAlarm!.time!)
        myAlarm!.time = Calendar.current.date(bySetting: .minute, value: editMinuteValue!, of: myAlarm!.time!)
        try? self.moc.save()
        print("Alarm values after save are \(getDateText(date: myAlarm!.time!))")
    }
    
    func convertToMillitaryTime(hourValue : Int, AmPm : Int) -> Int{
        if hourValue == 12 {
            if AmPm == 1{
                return 00
            } else {
                return 12
            }
        }
        return AmPm == 1 ? hourValue : hourValue + 12
    }
    
    func createAlarmNotification(){
        let content = UNMutableNotificationContent()
        content.title = "Alarm Going Off!"
        content.subtitle = "Alarm Set For \(getDateText(date: myAlarm?.time ?? Date()))"
        content.sound = UNNotificationSound.default

        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.hour,.minute,.second,], from: myAlarm!.time!), repeats: true)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func createDemoAlarm(){
        let content = UNMutableNotificationContent()
        content.title = "Alarm Going Off!"
        content.subtitle = "Alarm Set For \(getDateText(date: myAlarm?.time ?? Date()))"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func deleteAlarmNotification(){
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func correctCurrentAlarmDate(){
        print("Begin correcting current alarm date, current date is \(getDateText(date: myAlarm!.time!))")
        let alarmDay = Calendar.current.component(.day, from: (myAlarm?.time!)!)
        let currentDay = Calendar.current.component(.day, from: Date())
        if myAlarm!.time! < Date() || ((alarmDay != currentDay) && (alarmDay != currentDay + 1)){
            print("**ALARM TIME BEFORE CURRENT DATE**")
            myAlarm!.time = Calendar.current.date(bySetting: .year, value: Calendar.current.component(.year, from: Date()), of: myAlarm!.time!)
            myAlarm!.time = Calendar.current.date(bySetting: .month, value: Calendar.current.component(.month, from: Date()), of: myAlarm!.time!)
            myAlarm!.time = Calendar.current.date(bySetting: .day, value: Calendar.current.component(.day, from: Date()), of: myAlarm!.time!)
            if myAlarm!.time! < Date(){
                print("******INCREMENTING DATE*********")
                myAlarm!.time = Calendar.current.date(byAdding: .day, value: 1, to: myAlarm!.time!)
            }
            try? self.moc.save()
        }
        
        print("Done correcting current alarm date, now the date is \(getDateText(date: myAlarm!.time!))")
    }
    
    func getPermissions(){
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Permissions accepted")
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    func getDateText(date : Date = Date())->String{
         let time = date
         let timeFormatter = DateFormatter()
         timeFormatter.dateFormat = "MMMM dd yyyy, hh:mm a"
         let stringDate = timeFormatter.string(from: time)
         return stringDate
        }
    
    func getTimeText(date : Date = Date(), _ noAM : Bool = false)->String{
        let time = date
        let timeFormatter = DateFormatter()
        if noAM == false {
            timeFormatter.dateFormat = "hh:mm a"
        } else {
            timeFormatter.dateFormat = "hh:mm"
        }
        let timeDate = timeFormatter.string(from: time)
        return timeDate
    }
    
    func getEditingDate()->Date{
        var date = Date()
        date = Calendar.current.date(bySetting: .hour, value: editHourValue!, of: date)!
        date = Calendar.current.date(bySetting: .minute, value: editMinuteValue!, of: date)!
        return date
    }
    
    //Dictating Fuctions
    func dictateString(_ s : String, _ delay : Double = 0){
        syn.stopSpeaking(at: .immediate)
        let toSpeak = AVSpeechUtterance(string: s)
        toSpeak.voice = AVSpeechSynthesisVoice(language: "en-GB")
        toSpeak.preUtteranceDelay = delay
        syn.speak(toSpeak)
    }
    
    func dictateInitialInstructions(){
        dictateString("My VR alarm, tap the screen with one finger to hear instructions.")
    }
    
    func dictateMainPageInstructions(){
        dictateString("Instructions. Double tap the screen with one finger for time and alarm details. Swipe up with one finger to toggle alarm on or off. Full screen swipe left to edit alarm settings. Tap the screen with one finger to hear instructions again.")
    }
    
    func dictateTimeAndAlarmDetails(){
        print("Begin dictating alarm details")
        correctCurrentAlarmDate()
        print("Current date and time is \(getDateText()). Alarm status is : ", myAlarm?.status ?? false, ", Alarm time is : ", getDateText(date: myAlarm?.time ?? Date()))
        dictateString("Current date and time is \(getDateText()). Alarm is \(myAlarm!.status ? "On" : "Off"), set for \(getTimeText(date: myAlarm!.time!))")
    }
    
    func dictateAlarmToggleStatus(){
        print("Begin dictating alarm toggle status")
        correctCurrentAlarmDate()
        print("Alarm status is : ", myAlarm?.status ?? false)
        dictateString("Alarm is now \(myAlarm!.status ? " On and set for \(getTimeText(date: myAlarm!.time!))" : "Off")")
    }
    
    func dictateEditHourInstructions(){
        print("Begin dictating edit hour instructions")
        dictateString("Editing alarm. Edit hour, \(editHourValue!) O'clock, adjustable. Swipe up or down with one finger to adjust the value, double tap to confirm.")
    }
    
    func dictateEditHourInstructionsTap(){
        dictateString("Edit hour, \(editHourValue!) O'clock, adjustable. Swipe up or down with one finger to adjust the value, double tap to confirm. Full screen swipe right to cancel editing.")
    }
    
    func dictateEditHourUpdate(){
        print("Begin dictating edit hour update")
        dictateString("\(editHourValue!) O'clock")
    }
    
    func dictateEditMinuteInstructions(){
        print("Begin dictating edit minute instructions")
        dictateString("\(editHourValue!) O'clock confirmed. Edit minute, \(getTimeText(date: getEditingDate(), true)), adjustable. Swipe up or down with one finger to adjust the value by 15 minutes, double tap to confirm.")
    }
    
    func dictateEditMinuteInstructionsTap(){
        dictateString("Edit minute, \(getTimeText(date: getEditingDate(), true)), adjustable. Swipe up or down with one finger to adjust the value by 15 minutes, double tap to confirm. Full screen swipe right to cancel editing.")
    }
    
    func dictateEditMinuteUpdate(){
        print("Begin dictating edit minute update")
        dictateString("\(getTimeText(date: getEditingDate(), true))")
    }
    
    func dictateEditAMPMInstructions(){
        print("Begin dictating edit AMPM instructions")
        dictateString("\(getTimeText(date: getEditingDate(), true)) confirmed. Choose AM or PM. Swipe up to select AM, or swipe down to select PM.")
    }
    
    func dictateEditAMPMInstructionsTap(){
        dictateString("Choose AM or PM. Swipe up to select AM, or swipe down to select PM. Double tap to confirm. Full screen swipe right to cancel editing.")
    }
    
    func dictateEditAMPMUpdate(){
        print("Begin dictating edit AMPM update")
        dictateString("\(editAMPMValue == 1 ? "AM" : "PM") selected. Double tap to confirm.")
    }
    
    func dictateEditAlarmConfirmInstructions(){
        print("Begin Final Confirmation")
        dictateString("\(editAMPMValue == 1 ? "AM" : "PM") confirmed. Alarm set for \(getTimeText(date: getEditingDate(), true)) \(editAMPMValue == 1 ? "AM" : "PM"). Double tap to confirm. Or full screen swipe right to cancel editing.")
    }
    
    func dictateEditConfirmInstructionsTap(){
        dictateString("Alarm set for \(getTimeText(date: getEditingDate(), true)) \(editAMPMValue == 1 ? "AM" : "PM"). Double tap to confirm. Or full screen swipe right to cancel editing.")
    }
    
    func dictateEditAlarmConfirmUpdate(){
        print("Final Confirmation Selected")
        dictateString("Alarm for \(getTimeText(date: myAlarm!.time!, false)) confirmed and turned on. Returning to main page.")
    }
    
    func dictateCancelEnteringMainPage(){
        print("Canceling and entering main page")
        dictateString("Edit canceled, returning to main page.")
    }
}

class NotificationDelegate : NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        completionHandler([.badge, .banner, .sound])
    }
}

extension UIScreen{
   static let screenWidth = UIScreen.main.bounds.size.width
   static let screenHeight = UIScreen.main.bounds.size.height
   static let screenSize = UIScreen.main.bounds.size
}
