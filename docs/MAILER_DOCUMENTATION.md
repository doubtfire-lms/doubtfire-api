![Doubtfire Logo](http://puu.sh/lyClF/fde5bfbbe7.png)
# Overview

Welcome to a comprehensive guide of what the mailer task and deliverables are. This documetn serves as a guide for new people to understand if they would wish so to work on this miler task that we have all started. It also serves as a log book if they so wish to log on what their findings are, what they worked on, and what progress have been made towards a better mailer system in this case.

## Table of Contents

- [Overview](#Overview)
  - [Table of Contents](#table-of-contents)
  - [Getting started](#getting-started)
  - [Development Status Log](#development-status-log)
  - [Task Section](#task-section)
    - [Task Completed Log](#task-completed-log)
    - [Task Haven't Completed Log](#task-haven't-completed-log)
    - [Future Task Idea Log](#future-task-idea-log)
  - [Conclusion and Readme](#Conclusion-and-readme)

## Getting started

The **Mailer system** is purposed to send individual the right information regarding the their task for ontrack or any other information that can be relevent to the current user.

Here are the files that ould suggest to be useful for individual who are getting to know teh mailer in general.com

- [Send_status_email.rake] - This serves as the blue starting point where the information of the mailer week start date and the week end date are stored. Additionally the task comment and engagement are also packaged in this little array struct and passed off to the unit model for more processing.
- [Unit.rb] - In this file is where the unit model is located. What we need to look at is the function "send_weekly_email_satus". This function is set to validate the function and put more information such as the person who we needs to send the email to to and which one to do. If it is a staff, then they go to the staff version. The one we want to focus on is the project.
- [Project.rb] - In this file, you will find a lot of functions that relate to the send status email. A few that i would want everyone to focus on are listed below:
  - Top_task: This function serve tocalculate the task that need to be presented to the person in the email. It generates a set of task that would be able to be priority task and provide datas such as the task status, the due date and the task name.
  - send_weekly_status_email - This function serves as the mail connector that passes through all the necessary information through ot the mail processor file.
- [Notificcations_mailer] - In this file, you will find the mail processing system where everything is set up for the sending. It connects the data and provides resources that can connect ot the actual email template and fill those vairables with the appropriate data aloccated.

## Development Status log

{10/18/2021}

- So far we have completed some task that would be able to continue on and serves as a fresh idea that would help other individuals in mailer system work for ontrack. We have improved on the existing template for the mailer notificaiton to include a due date that would help the person in question in knowing when their task would need to be done by. This serves as a better-ment of the system as a whole as this could really help someone who is in need to find out what the exact date of a certain would be due by without the inconvenince of really going through and logging in to the ontrack system as it requires a lot of time to see what is needed to be done and as a genral thought from some feed back that was obtained, a very hard ui to navigate through. Adding to that, we also made a the top task that was mentioned above to include all task and not only just calculate the top 5 task that would need to be done. We feel like only having 5 top task was sometimes be a troublesome manner as we thought of a few scenarios where the person could be blindside themselves into thinking that their would only by 5 task that were needed to be done. Through reseach me and my team debated whetehr the 5 task would be the best way to motivate the person into trying to do teh task but came to a deceision that letting the person know that not only were those 5 tasks were motivative enough for people to do their task, but they might use it as an excuse to say that it was only 5 task. This serves a mental purpose as well for students to get up, finished as many task as they can to the best of their ability and feel good about achiving something as well.

- Another code that we have started was the new task status update deature for the mail notification system. This feature serves as a, as the name implies, a notication for a user to know if a task has been marked yet or not. This decision was made to help those who are asking for help with them knowing when a task has been marked off. Many feedback suggest that, not all people are very attentive to their school work as most have general outside work or outside yask that they complete daily that can distract them from checking a marked off task. While the whole system have not been completed, It serves as a starting point and new idea for future task groups to work one, if they wish to do so. We have completed a template with the "task_status.html.erb" and "task_status.text.erb" to help with in developing this system.

- The last main core thing that we already worked on is a testing system which would actually send us a mock email so that we can see the sytem is working properly and serves as a easier way of trying to test the output. While the code itself does not work in the code itself, One of my teammate, whom is Jason(@kolpanhabotr phat) on teams, have heavily put a warning and options on what to do with the testing code. A good amount of research is needed, to be able to develop this code as the general code only works with a mock setup rails system on your local computer.

## Task section

### Task Completed Log

This section serves as a log pupose for completed task. Please log your completion of task here so that the future members of the Mail notification task is informed of the past achievements

- [Enhancement - Due date] - get due date from the top task and add it to the mailer template

- [Enhancement - Show All Task] - change the top task to show all task within the unit instead of just 5 task that the user can wbe working on


### Task Haven't Completed Log

This section serves as a log for uncompleted task that have been started. Task in this section can be picked up by a group to work on and complete. It can be bug fixing or finishing past un-completed deliverables. FOr people who are filling out this section please explain in bullet points what you have did and whether it is working or not. Also if it is working on your own system, then please put "PT" Which stands For "Personaly Tested" to let the people know.

- [Feature - Task Status notification mailer] - Adds a new feature where the mail will send a notification if a task has been checked by the tutor.
  - Completed a mock template for the task status update (task_status.html.erb) & (task_status.text.erb)
  - PT
  - Need to include relevent files to connect the system together

### Future Task Idea Log

In this Section, we can log down future ideas that we come come back to or for future peeople to work on. NOTE: If you have started one of these task, please move them to the Task haven't completed log and write down all the necessary information as well so that we can continue on the idea that people can work on

Type                | Description
--------------------|-----------------------------------------------------------------------------------------------------------------------------------------------
Enhance             | Enhance the email template to include all task from all enrolled units in one email rather than 1 mail per unit
Enhance             | Give the task a link where teh user can click and be redirected to the task on ontrack

## Conclusion and Readme

Conclusion. 

  The aim for this task squad is to improve the the mail system on the ontrack system so that everyone who works on the system would be able to wor together to improve veryones daily lives by reminding them of information relevent to them in order for them to achive success. The aim of this documentation is to log all progress that have been done by evryone over the course of the journey of this system. It also serves a long time purpose on what to look back on, what was achived and what we need to look at in the future. I urged for those who is reading this to put in the relevent information so that we can keep track of the progress made by all of our combined efforts.