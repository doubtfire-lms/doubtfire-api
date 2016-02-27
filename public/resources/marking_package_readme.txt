Doubtfire Offline Marking Package
=================================

1. To mark, open marks.csv in your favourite spreadsheet or text editor.

2. Open a student's PDF submission file. You may choose to annotate or comment
   on this PDF file.

3. A student may decide that their work is:

    * Ready to Mark (or 'rtm'), or
    * Needs Help (or 'needs_help').

   This is indicated in the "Status" column for the respective task row in the
   marks.csv file.

   Once you decide what status to update a student's work to, change the "Status"
   column value to one of the following:

    * 'discuss' or 'd' -        The student has completed work to a satisfactory
                                standard and you will discuss the work with them
                                at the next tutorial.

    * 'demonstrate' or 'demo' - The same as 'discuss', but a reminder for you to
                                ask the student to show you the work in class
                                (i.e., prove to you that the code works).

    * 'fix' -                   The student has made some errors and you will
                                want them to make fixes to their submission, and
                                resubmit their work for re-correction at a later
                                date.

    * 'do_not_resubmit' -       The student has consistently submitted the same
                                work without making required fixes. This indicates
                                that the student should fix the work themselves
                                and include it in their portfolio where staff
                                will reassess it.

    * 'redo' -                  The student has completely misunderstood what the
                                task asked of them, or have completed unrelated
                                files to Doubtfire. You want them to start the
                                task again from scratch.

    * 'fail' -                  The student has failed this task and will no longer
                                have any more attempts at uploading further work.
                                Use this sparingly.

4. Your previous comment and the student's previous comment will be present in the
   "Student's Last Comment" and "Your Last Comment" column, respectively. You may
   choose to add a new comment to this in the "New Comment" column.

5. If the task is a graded task, you should set the value of the "New Grade" column
   to one of:

   * 'p'  - for a task that was completed to a Pass standard
   * 'c'  - for a task that was completed to a Credit standard
   * 'd'  - for a task that was completed to a Distinction standard
   * 'hd' - for a task that was completed to a High Distinction standard

6. Re-zip the entire package again, including each student's username folder and
   marks.csv. Alternatively, if you haven't made any annotations to students' work
   you can chose to upload just the marks.csv file instead.

   To do this, click the "Mark Offline" button, select either the "Upload Marked"
   or "Upload marks.csv" buttons in the modal dialog and upload.

   Users on OS X should read the note below regarding a zipping issue.


Zipping issue with OS X
=======================

If you are an OS X user, you may encounter with Doubtfire rejecting your re-zipped
package.

If you do encounter this, please use the terminal to re-zip:

    $ cd /path/to/unzipped/folder/like/2016-02-23-COS12345-adoubtfire
    $ zip -r ../upload.zip .

Then upload 'upload.zip' to Doubtfire instead.
