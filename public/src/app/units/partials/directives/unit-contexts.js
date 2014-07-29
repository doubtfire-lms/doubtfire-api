var update_task_stats;
update_task_stats = function (stats_array, new_stats_str) {
  var i, value, _ref, _results;
  _ref = new_stats_str.split('|');
  _results = [];
  for (i in _ref) {
    value = _ref[i];
    _results.push(stats_array[i].value = 100 * value);
  }
  return _results;
};
angular.module('doubtfire.units.partials.contexts', ['doubtfire.units.partials.modals']).filter('startFrom', function () {
  return function (input, start) {
    start = +start;
    if (input) {
      return input.slice(start);
    } else {
      return input;
    }
  };
}).directive('studentUnitTasks', function () {
  return {
    replace: false,
    restrict: 'E',
    templateUrl: 'units/partials/templates/student-unit-tasks.tpl.html',
    scope: {
      student: '=student',
      project: '=project',
      onChange: '=onChange',
      studentProjectId: '=studentProjectId',
      taskDef: '=taskDef',
      unit: '=unit',
      assessingUnitRole: '=assessingUnitRole'
    },
    controller: [
      '$scope',
      '$modal',
      'Project',
      function ($scope, $modal, Project) {
        var showProject, updateChart;
        $scope.statusClass = function (status) {
          return _.trim(_.dasherize(status));
        };
        $scope.statusText = function (status) {
          return statusLabels[status];
        };
        showProject = function () {
          return $scope.tasks = $scope.project.tasks.map(function (task) {
            var td;
            td = $scope.taskDef(task.task_definition_id)[0];
            task.task_abbr = td.abbr;
            task.task_desc = td.desc;
            task.task_name = td.name;
            task.task_upload_requirements = td.upload_requirements;
            task.status_txt = statusLabels[task.status];
            return task;
          });
        };
        updateChart = false;
        if ($scope.project) {
          showProject();
          updateChart = true;
        } else {
          Project.get({ id: $scope.studentProjectId }, function (project) {
            $scope.project = project;
            return showProject();
          });
        }
        return $scope.showAssessTaskModal = function (task) {
          return $modal.open({
            controller: 'AssessTaskModalCtrl',
            templateUrl: 'tasks/partials/templates/assess-task-modal.tpl.html',
            resolve: {
              task: function () {
                return task;
              },
              student: function () {
                return $scope.student;
              },
              project: function () {
                return $scope.project;
              },
              assessingUnitRole: function () {
                return $scope.assessingUnitRole;
              },
              onChange: function () {
                return $scope.onChange;
              }
            }
          });
        };
      }
    ]
  };
}).directive('studentUnitContext', function () {
  return {
    replace: true,
    restrict: 'E',
    templateUrl: 'units/partials/templates/student-unit-context.tpl.html',
    controller: [
      '$scope',
      '$rootScope',
      'UnitRole',
      function ($scope, $rootScope, UnitRole) {
        if ($rootScope.assessingUnitRole != null && $rootScope.assessingUnitRole.unit_id === $scope.unitRole.unit_id) {
          $scope.assessingUnitRole = $rootScope.assessingUnitRole;
          return $scope.showBack = true;
        } else {
          $scope.assessingUnitRole = $scope.unitRole;
          return $scope.showBack = false;
        }
      }
    ]
  };
}).directive('tutorUnitContext', function () {
  return {
    replace: true,
    restrict: 'E',
    templateUrl: 'units/partials/templates/tutor-unit-context.tpl.html',
    controller: [
      '$scope',
      '$rootScope',
      '$modal',
      'Project',
      'Students',
      'filterFilter',
      'alertService',
      function ($scope, $rootScope, $modal, Project, Students, filterFilter, alertService) {
        var prepAccordion, unwatchFn, update_project_details;
        $scope.accordionHeight = 100;
        $scope.accordionReady = false;
        prepAccordion = function () {
          $scope.accordionHeight = $scope.taskCount() / 5 * 32;
          return $scope.accordionReady = true;
        };
        if (!$scope.unitLoaded) {
          unwatchFn = $scope.$watch(function () {
            return $scope.unitLoaded;
          }, function (value) {
            if (value) {
              prepAccordion();
              return unwatchFn();
            } else {
              return $scope.accordionReady = false;
            }
          });
        } else {
          prepAccordion();
        }
        $scope.reverse = false;
        $scope.statusClass = function (status) {
          return _.trim(_.dasherize(status));
        };
        $scope.barLargerZero = function (bar) {
          return bar.value > 0;
        };
        $scope.currentPage = 1;
        $scope.maxSize = 5;
        $scope.pageSize = 15;
        Students.query({ unit_id: $scope.unitRole.unit_id }, function (students) {
          return $scope.students = students.map(function (student) {
            student.open = false;
            student.tutorial = $scope.tutorialFromId(student.tute)[0];
            student.task_stats = [
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[0]))
              },
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[1]))
              },
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[2]))
              },
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[3]))
              },
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[4]))
              },
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[5]))
              },
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[6]))
              },
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[7]))
              },
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[8]))
              },
              {
                value: 0,
                type: _.trim(_.dasherize(statusKeys[9]))
              }
            ];
            update_task_stats(student.task_stats, student.stats);
            return student;
          });
        });
        update_project_details = function (student, project) {
          var _this = this;
          update_task_stats(student.task_stats, project.stats);
          if (student.project) {
            _.each(student.project.tasks, function (task) {
              return task.status = _.where(project.tasks, { task_definition_id: task.task_definition_id })[0].status;
            });
          }
          return alertService.add('success', 'Status updated.', 2000);
        };
        $scope.transitionWeekEnd = function (student) {
          return Project.update({
            id: student.project_id,
            trigger: 'trigger_week_end'
          }).$promise.then(function (project) {
            return update_project_details(student, project);
          });
        };
        $scope.assessingUnitRole = $scope.unitRole;
        return $scope.showEnrolModal = function () {
          return $modal.open({
            templateUrl: 'units/partials/templates/enrol-student-modal.tpl.html',
            controller: 'EnrolStudentModalCtrl',
            resolve: {
              unit: function () {
                return $scope.unit;
              },
              projects: function () {
                return $scope.students;
              }
            }
          });
        };
      }
    ]
  };
}).directive('staffAdminUnitContext', function () {
  return {
    replace: true,
    restrict: 'E',
    templateUrl: 'units/partials/templates/staff-admin-context.tpl.html',
    controller: [
      '$scope',
      '$rootScope',
      'Unit',
      'UnitRole',
      function ($scope, $rootScope, Unit, UnitRole) {
        var temp, users;
        temp = [];
        users = [];
        $scope.changeRole = function (unitRole, role_id) {
          unitRole.role_id = role_id;
          unitRole.unit_id = $scope.unit.id;
          return UnitRole.update({
            id: unitRole.id,
            unit_role: unitRole
          });
        };
        $scope.addSelectedStaff = function () {
          var staff, tutorRole;
          staff = $scope.selectedStaff;
          $scope.selectedStaff = null;
          if (!$scope.unit.staff) {
            $scope.unit.staff = [];
          }
          tutorRole = UnitRole.create({
            unit_id: $scope.unit.id,
            user_id: staff.id,
            role: 'Tutor'
          });
          return $scope.unit.staff.push(tutorRole);
        };
        $scope.findStaffUser = function (id) {
          var staff, _i, _len, _ref;
          _ref = $scope.staff;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            staff = _ref[_i];
            if (staff.id === id) {
              return staff;
            }
          }
        };
        $scope.filterStaff = function (staff) {
          return !_.find($scope.unit.staff, function (listStaff) {
            return staff.id === listStaff.user_id;
          });
        };
        return $scope.removeStaff = function (staff) {
          var staffUser;
          $scope.unit.staff = _.without($scope.unit.staff, staff);
          UnitRole['delete']({ id: staff.id });
          return staffUser = $scope.findStaffUser(staff.user_id);
        };
      }
    ]
  };
}).directive('taskAdminUnitContext', function () {
  return {
    replace: true,
    restrict: 'E',
    templateUrl: 'units/partials/templates/task-admin-context.tpl.html',
    controller: [
      '$scope',
      '$modal',
      '$rootScope',
      'TaskCSV',
      'Unit',
      function ($scope, $modal, $rootScope, TaskCSV, Unit) {
        $scope.tasksFileUploader = TaskCSV.fileUploader($scope);
        $scope.submitTasksUpload = function () {
          return $scope.tasksFileUploader.uploadTaskCSV($scope.unit);
        };
        $scope.requestTasksExport = function () {
          return TaskCSV.downloadFile($scope.unit);
        };
        $scope.currentPage = 1;
        $scope.maxSize = 5;
        $scope.pageSize = 15;
        $scope.editTask = function (task) {
          return $modal.open({
            controller: 'TaskEditModalCtrl',
            templateUrl: 'units/partials/templates/task-edit-modal.tpl.html',
            resolve: {
              task: function () {
                return task;
              },
              isNew: function () {
                return false;
              },
              unit: function () {
                return $scope.unit;
              }
            }
          });
        };
        return $scope.createTask = function () {
          var task;
          task = {
            target_date: new Date(),
            required: true,
            upload_requirements: []
          };
          return $modal.open({
            controller: 'TaskEditModalCtrl',
            templateUrl: 'units/partials/templates/task-edit-modal.tpl.html',
            resolve: {
              task: function () {
                return task;
              },
              isNew: function () {
                return true;
              },
              unit: function () {
                return $scope.unit;
              }
            }
          });
        };
      }
    ]
  };
}).directive('adminUnitContext', function () {
  return {
    replace: true,
    restrict: 'E',
    templateUrl: 'units/partials/templates/unit-admin-context.tpl.html',
    controller: [
      '$scope',
      '$state',
      '$rootScope',
      'Unit',
      'alertService',
      function ($scope, $state, $rootScope, Unit, alertService) {
        $scope.format = 'yyyy-MM-dd';
        $scope.initDate = new Date('2016-04-20');
        $scope.startOpened = $scope.endOpened = $scope.opened = false;
        $scope.dateOptions = {
          formatYear: 'yy',
          startingDay: 1
        };
        return $scope.saveUnit = function () {
          if ($scope.unit.convenors) {
            delete $scope.unit.convenors;
          }
          if ($scope.unit.id === -1) {
            return Unit.create({ unit: $scope.unit }, function (unit) {
              return $scope.saveSuccess(unit);
            });
          } else {
            return Unit.update({
              id: $scope.unit.id,
              unit: $scope.unit
            }, function (unit) {
              alertService.add('success', 'Unit updated.', 2000);
              return $state.transitionTo('admin/units#index');
            });
          }
        };
      }
    ]
  };
}).directive('tutorialUnitContext', function () {
  return {
    replace: true,
    restrict: 'E',
    templateUrl: 'units/partials/templates/tutorial-admin-context.tpl.html',
    controller: [
      '$scope',
      '$modal',
      '$rootScope',
      'Unit',
      'UnitRole',
      function ($scope, $modal, $rootScope, Unit, UnitRole) {
        $scope.editTutorial = function (tutorial) {
          return $modal.open({
            controller: 'TutorialModalCtrl',
            templateUrl: 'units/partials/templates/tutorial-modal.tpl.html',
            resolve: {
              tutorial: function () {
                return tutorial;
              },
              isNew: function () {
                return false;
              },
              tutors: function () {
                return $scope.unit.staff;
              },
              unit: function () {
                return $scope.unit;
              }
            }
          });
        };
        return $scope.createTutorial = function () {
          var d, tutorial;
          d = new Date();
          d.setHours(8);
          d.setMinutes(30);
          tutorial = {
            abbreviation: 'LA1-??',
            meeting_day: 'Monday',
            meeting_time: d,
            meeting_location: 'ATC???'
          };
          return $modal.open({
            controller: 'TutorialModalCtrl',
            templateUrl: 'units/partials/templates/tutorial-modal.tpl.html',
            resolve: {
              tutorial: function () {
                return tutorial;
              },
              isNew: function () {
                return true;
              },
              tutors: function () {
                return $scope.unit.staff;
              },
              unit: function () {
                return $scope.unit;
              }
            }
          });
        };
      }
    ]
  };
}).directive('enrolStudentsContext', function () {
  return {
    replace: true,
    restrict: 'E',
    templateUrl: 'units/partials/templates/enrol-student-context.tpl.html',
    controller: [
      '$scope',
      'StudentEnrolmentCSV',
      function ($scope, StudentEnrolmentCSV) {
        $scope.seFileUploader = StudentEnrolmentCSV.fileUploader($scope);
        $scope.submitSEUpload = function () {
          return $scope.seFileUploader.uploadStudentEnrolmentCSV($scope.unit);
        };
        $scope.requestSEExport = function () {
          return StudentEnrolmentCSV.downloadFile($scope.unit);
        };
        $scope.currentPage = 1;
        $scope.maxSize = 5;
        return $scope.pageSize = 15;
      }
    ]
  };
});