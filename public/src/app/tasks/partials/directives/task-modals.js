angular.module('doubtfire.tasks.partials.modals', []).controller('AssessTaskModalCtrl', [
  '$scope',
  '$modalInstance',
  '$modal',
  'task',
  'student',
  'project',
  'onChange',
  'assessingUnitRole',
  'Task',
  'alertService',
  function ($scope, $modalInstance, $modal, task, student, project, onChange, assessingUnitRole, Task, alertService) {
    $scope.task = task;
    $scope.$watch('task.status', function () {
      $scope.taskClass = _.trim(_.dasherize($scope.task.status), '-');
      return $scope.taskStatusLabel = statusLabels[$scope.task.status];
    });
    $scope.triggerTransition = function (status) {
      var oldStatus;
      oldStatus = $scope.task.status;
      if (status === 'ready_to_mark' && $scope.task.task_upload_requirements.length > 0) {
        $modalInstance.close(oldStatus);
        return $modal.open({
          controller: 'SubmitTaskModalCtrl',
          templateUrl: 'tasks/partials/templates/submit-task-modal.tpl.html',
          resolve: {
            task: function () {
              return $scope.task;
            }
          }
        }).result.then(function (val) {
        }, function () {
          $scope.task.status = oldStatus;
          return alertService.add('info', 'Upload cancelled: status was reverted.', 2000);
        });
      } else {
        return Task.update({
          id: $scope.task.id,
          trigger: status
        }).$promise.then(function (value) {
          $scope.task.status = value.status;
          $modalInstance.close(status);
          if (student != null && student.task_stats != null) {
            update_task_stats(student.task_stats, value.new_stats);
          }
          if (value.status === status) {
            alertService.add('success', 'Status saved.', 2000);
            if (onChange) {
              return onChange();
            }
          } else {
            return alertService.add('danger', 'Status change was not changed.', 2000);
          }
        }, function (value) {
          $modalInstance.close(value.data.error);
          $scope.task.status = oldStatus;
          return alertService.add('danger', value.data.error, 4000);
        });
      }
    };
    $scope.readyToAssessStatuses = [
      'ready_to_mark',
      'not_submitted'
    ];
    $scope.engagementStatuses = [
      'working_on_it',
      'need_help'
    ];
    $scope.orderedStatuses = [
      'not_submitted',
      'need_help',
      'working_on_it',
      'ready_to_mark'
    ];
    $scope.tutorStatuses = [
      'fix_and_include',
      'redo',
      'fix_and_resubmit',
      'discuss'
    ];
    $scope.completeStatuses = ['complete'];
    if (assessingUnitRole != null) {
      $scope.role = assessingUnitRole.role;
    } else {
      $scope.role = 'Student';
    }
    $scope.activeClass = function (status) {
      if (status === $scope.task.status) {
        return 'active';
      } else {
        return '';
      }
    };
    return $scope.taskEngagementConfig = {
      readyToAssess: $scope.readyToAssessStatuses.map(function (status) {
        return {
          status: status,
          label: statusLabels[status],
          iconClass: statusIcons[status]
        };
      }),
      engagement: $scope.engagementStatuses.map(function (status) {
        return {
          status: status,
          label: statusLabels[status],
          iconClass: statusIcons[status]
        };
      }),
      all: $scope.orderedStatuses.map(function (status) {
        return {
          status: status,
          label: statusLabels[status],
          iconClass: statusIcons[status],
          taskClass: _.trim(_.dasherize(status), '-')
        };
      }),
      tutorTriggers: $scope.tutorStatuses.map(function (status) {
        return {
          status: status,
          label: statusLabels[status],
          iconClass: statusIcons[status],
          taskClass: _.trim(_.dasherize(status), '-')
        };
      }),
      complete: $scope.completeStatuses.map(function (status) {
        return {
          status: status,
          label: statusLabels[status],
          iconClass: statusIcons[status],
          taskClass: _.trim(_.dasherize(status), '-')
        };
      })
    };
  }
]).controller('SubmitTaskModalCtrl', [
  '$scope',
  '$modalInstance',
  'TaskSubmission',
  'task',
  'alertService',
  function ($scope, $modalInstance, TaskSubmission, task, alertService) {
    $scope.task = task;
    $scope.uploadRequirements = task.task_upload_requirements;
    $scope.fileUploader = TaskSubmission.fileUploader($scope, task);
    $scope.submitUpload = function () {
      return $scope.fileUploader.uploadEnqueuedFiles();
    };
    $scope.clearUploads = function () {
      return $scope.fileUploader.clearQueue();
    };
    return $scope.close = function () {
      return $modalInstance.close();
    };
  }
]);