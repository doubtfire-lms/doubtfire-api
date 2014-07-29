angular.module('doubtfire.projects', [
  'doubtfire.units.partials',
  'doubtfire.projects.partials'
]).config([
  '$stateProvider',
  function ($stateProvider) {
    return $stateProvider.state('projects#show', {
      url: '/projects/:projectId?unitRole',
      views: {
        main: {
          controller: 'ProjectsShowCtrl',
          templateUrl: 'projects/projects-show.tpl.html'
        },
        header: {
          controller: 'BasicHeaderCtrl',
          templateUrl: 'common/header.tpl.html'
        }
      },
      data: {
        pageTitle: '_Home_',
        roleWhitelist: [
          'Student',
          'Tutor',
          'Convenor',
          'Admin'
        ]
      }
    });
  }
]).controller('ProjectsShowCtrl', [
  '$scope',
  '$state',
  '$stateParams',
  'Project',
  'Unit',
  'UnitRole',
  'headerService',
  'alertService',
  function ($scope, $state, $stateParams, Project, Unit, UnitRole, headerService, alertService) {
    $scope.unitLoaded = false;
    $scope.studentProjectId = $stateParams.projectId;
    $scope.projectLoaded = false;
    $scope.taskDef = function (taskDefId) {
      return _.where($scope.unit.task_definitions, { id: taskDefId });
    };
    return Project.get({ id: $scope.studentProjectId }, function (project) {
      headerService.clearMenus();
      $scope.project = project;
      $scope.submittedTasks = [];
      if (project) {
        Unit.get({ id: project.unit_id }, function (unit) {
          $scope.unit = unit;
          $scope.tasks = $scope.project.tasks.map(function (task) {
            var td;
            td = $scope.taskDef(task.task_definition_id)[0];
            task.task_abbr = td.abbr;
            task.task_desc = td.desc;
            task.task_name = td.name;
            task.task_upload_requirements = td.upload_requirements;
            task.status_txt = statusLabels[task.status];
            return task;
          });
          $scope.submittedTasks = _.filter($scope.tasks, function (task) {
            return _.contains([
              'ready_to_mark',
              'discuss',
              'complete',
              'fix_and_resubmit',
              'fix_and_include',
              'redo'
            ], task.status);
          });
          $scope.submittedTasks = _.sortBy($scope.submittedTasks, function (t) {
            return t.task_abbr;
          }).reverse();
          return $scope.unitLoaded = true;
        });
        if ($stateParams.unitRole != null) {
          UnitRole.get({ id: $stateParams.unitRole }, function (unitRole) {
            if (unitRole.unit_id === $scope.unit.id) {
              return $scope.assessingUnitRole = unitRole;
            }
          });
        }
        $scope.burndownData = project.burndown_chart_data;
        return $scope.projectLoaded = true;
      }
    });
  }
]);