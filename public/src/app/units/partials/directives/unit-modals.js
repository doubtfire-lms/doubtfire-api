angular.module('doubtfire.units.partials.modals', []).controller('TutorialModalCtrl', [
  '$scope',
  '$modalInstance',
  'tutorial',
  'isNew',
  'tutors',
  'unit',
  'Tutorial',
  'alertService',
  function ($scope, $modalInstance, tutorial, isNew, tutors, unit, Tutorial, alertService) {
    $scope.tutorial = tutorial;
    $scope.isNew = isNew;
    $scope.tutors = tutors;
    return $scope.saveTutorial = function () {
      var save_data;
      save_data = _.omit(tutorial, 'tutor', 'tutor_name', 'meeting_time', 'data');
      save_data.tutor_id = tutorial.tutor.user_id;
      if (tutorial.meeting_time.getHours) {
        save_data.meeting_time = tutorial.meeting_time.getHours() + ':' + tutorial.meeting_time.getMinutes();
      }
      if (isNew) {
        save_data.unit_id = unit.id;
        return Tutorial.create({ tutorial: save_data }).$promise.then(function (response) {
          $modalInstance.close(response);
          unit.tutorials.push(response);
          return alertService.add('success', 'Tutorial Added', 5000);
        }, function (response) {
          if (response.data.error != null) {
            return alertService.add('danger', 'Error: ' + response.data.error, 5000);
          }
        });
      } else {
        return Tutorial.update({
          id: tutorial.id,
          tutorial: save_data
        }).$promise.then(function (response) {
          $modalInstance.close(response);
          tutorial.tutor = response.tutor;
          tutorial.tutor_name = response.tutor_name;
          return alertService.add('success', 'Tutorial Updated', 5000);
        }, function (response) {
          if (response.data.error != null) {
            return alertService.add('danger', 'Error: ' + response.data.error, 5000);
          }
        });
      }
    };
  }
]).controller('UnitModalCtrl', [
  '$scope',
  '$modalInstance',
  'Unit',
  'convenors',
  'unit',
  function ($scope, $modalInstance, Unit, convenors, unit) {
    $scope.unit = unit;
    $scope.modalState = {};
    $scope.availableConvenors = angular.copy(convenors);
    $scope.addSelectedConvenor = function () {
      var convenor;
      convenor = $scope.modalState.selectedConvenor;
      $scope.modalState.selectedConvenor = null;
      $scope.unit.convenors.push(convenor);
      return $scope.availableConvenors = _.without($scope.availableConvenors, convenor);
    };
    $scope.removeConvenor = function (convenor) {
      $scope.unit.convenors = _.without($scope.unit.convenors, convenor);
      return $scope.availableConvenors.push(convenor);
    };
    return $scope.saveUnit = function () {
      return Unit.create({ unit: $scope.unit });
    };
  }
]).controller('EnrolStudentModalCtrl', [
  '$scope',
  '$modalInstance',
  'Project',
  'unit',
  'projects',
  function ($scope, $modalInstance, Project, unit, projects) {
    $scope.unit = unit;
    return $scope.enrolStudent = function (student_id, tutorial) {
      return Project.create({
        unit_id: unit.id,
        student_num: student_id,
        tutorial_id: tutorial ? tutorial.id : null
      }, function (project) {
        projects.push(project);
        return $modalInstance.close();
      });
    };
  }
]).controller('TaskEditModalCtrl', [
  '$scope',
  '$modalInstance',
  'TaskDefinition',
  'task',
  'unit',
  'alertService',
  'isNew',
  function ($scope, $modalInstance, TaskDefinition, task, unit, alertService, isNew) {
    $scope.unit = unit;
    $scope.task = task;
    $scope.isNew = isNew;
    $scope.open = function ($event) {
      $event.preventDefault();
      $event.stopPropagation();
      return $scope.opened = true;
    };
    $scope.addUpReq = function () {
      var newLength, newUpReq;
      newLength = $scope.task.upload_requirements.length + 1;
      newUpReq = {
        key: 'file' + (newLength - 1),
        name: '',
        type: 'code'
      };
      return $scope.task.upload_requirements.push(newUpReq);
    };
    $scope.removeUpReq = function (upReq) {
      return $scope.task.upload_requirements = $scope.task.upload_requirements.filter(function (anUpReq) {
        return anUpReq.key !== upReq.key;
      });
    };
    return $scope.saveTask = function () {
      task = $scope.task;
      task.abbreviation = $scope.task.abbr;
      task.weighting = $scope.task.weight;
      task.unit_id = $scope.unit.id;
      task.upload_requirements = JSON.stringify($scope.task.upload_requirements);
      task.description = $scope.task.desc;
      if ($scope.isNew) {
        return TaskDefinition.create({ task_def: task }).$promise.then(function (response) {
          $modalInstance.close(response);
          $scope.unit.task_definitions.push(response);
          return alertService.add('success', '' + response.name + ' Added', 5000);
        }, function (response) {
          if (response.data.error != null) {
            return alertService.add('danger', 'Error: ' + response.data.error, 5000);
          }
        });
      } else {
        return TaskDefinition.update({
          id: task.id,
          task_def: task
        }).$promise.then(function (response) {
          $modalInstance.close(response);
          $scope.unit.task_definitions.push(response);
          return alertService.add('success', '' + response.name + ' Updated', 5000);
        }, function (response) {
          if (response.data.error != null) {
            return alertService.add('danger', 'Error: ' + response.data.error, 5000);
          }
        });
      }
    };
  }
]);