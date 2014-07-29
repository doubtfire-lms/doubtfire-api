angular.module('doubtfire.projects.partials.contexts', []).directive('progressInfo', function () {
  return {
    restrict: 'E',
    templateUrl: 'projects/partials/templates/progress-info.tpl.html',
    controller: [
      '$scope',
      '$state',
      '$stateParams',
      'Project',
      'Unit',
      'UnitRole',
      'headerService',
      'alertService',
      function ($scope, $state, $stateParams, Project, Unit, UnitRole, headerService, alertService) {
        $scope.studentProjectId = $stateParams.projectId;
        $scope.xAxisTickFormat_Date_Format = function () {
          return function (d) {
            return d3.time.format('%b %d')(new Date(d * 1000));
          };
        };
        $scope.yAxisTickFormat_Percent_Format = function () {
          return function (d) {
            return d3.format(',%')(d);
          };
        };
        $scope.colorFunction = function () {
          return function (d, i) {
            if (i === 0) {
              return '#AAAAAA';
            } else if (i === 1) {
              return '#777777';
            } else if (i === 2) {
              return '#336699';
            } else {
              return '#E01B5D';
            }
          };
        };
        $scope.xAxisClipNegBurndown = function () {
          return function (d) {
            var c, m, originX, pt1x, pt1y, pt2x, pt2y, _ref, _ref1;
            if (d[1] < 0) {
              originX = $scope.burndownData[0].values[0][0];
              _ref = [
                originX,
                1
              ], pt1x = _ref[0], pt1y = _ref[1];
              _ref1 = [
                d[0],
                d[1]
              ], pt2x = _ref1[0], pt2y = _ref1[1];
              m = (pt2y - pt1y) / (pt2x - pt1x);
              c = pt1y - m * pt1x;
              return -c / m;
            } else {
              return d[0];
            }
          };
        };
        $scope.yAxisClipNegBurndown = function () {
          return function (d) {
            if (d[1] < 0) {
              return 0;
            } else {
              return d[1];
            }
          };
        };
        $scope.updateBurndownChart = function () {
          return Project.get({ id: $scope.studentProjectId }, function (project) {
            return $scope.burndownData = project.burndown_chart_data;
          });
        };
        $scope.lateEndDate = function () {
          return new Date(+new Date($scope.unit.end_date) + 1209600000).getTime() / 1000;
        };
        $scope.tutorialFromId = function (tuteId) {
          return _.where($scope.unit.tutorials, { id: tuteId });
        };
        return $scope.taskCount = function () {
          return $scope.unit.task_definitions.length;
        };
      }
    ]
  };
}).directive('taskList', function () {
  return {
    restrict: 'E',
    templateUrl: 'projects/partials/templates/task-list.tpl.html',
    controller: [
      '$scope',
      '$modal',
      'User',
      'Unit',
      function ($scope, $modal, User, Unit) {
      }
    ]
  };
}).directive('labList', function () {
  return {
    restrict: 'E',
    templateUrl: 'projects/partials/templates/lab-list.tpl.html',
    controller: [
      '$scope',
      '$modal',
      'User',
      'Project',
      function ($scope, $modal, User, Project) {
        $scope.sortOrder = 'abbreviation';
        return $scope.setTutorial = function (id) {
          return Project.update({
            id: $scope.project.project_id,
            tutorial_id: id
          }).$promise.then(function (project) {
            return $scope.project.tute = project.tute;
          });
        };
      }
    ]
  };
}).directive('taskFeedback', function () {
  return {
    restrict: 'E',
    templateUrl: 'projects/partials/templates/task-feedback.tpl.html',
    controller: [
      '$scope',
      '$modal',
      'TaskFeedback',
      function ($scope, $modal, TaskFeedback) {
        var loadPdf, renderPdf;
        $scope.pdfLoaded = false;
        loadPdf = function (task) {
          return PDFJS.getDocument(TaskFeedback.getTaskUrl(task)).then(function (pdf) {
            $scope.pdf = pdf;
            $scope.pageNo = 1;
            return renderPdf();
          });
        };
        renderPdf = function () {
          $scope.pdfLoaded = false;
          return $scope.pdf.getPage($scope.pageNo).then(function (page) {
            var canvas, context, renderContext, viewport;
            viewport = page.getViewport(1);
            canvas = document.getElementById('pdf');
            context = canvas.getContext('2d');
            canvas.height = viewport.height;
            canvas.width = viewport.width;
            renderContext = {
              canvasContext: context,
              viewport: viewport
            };
            return page.render(renderContext).then(function () {
              return $scope.pdfLoaded = true;
            });
          });
        };
        $scope.nextPage = function () {
          if ($scope.pageNo < $scope.pdf.numPages && $scope.pdfLoaded) {
            $scope.pageNo++;
            return renderPdf();
          }
        };
        $scope.prevPage = function () {
          if ($scope.pageNo > 0 && $scope.pdfLoaded) {
            $scope.pageNo--;
            return renderPdf();
          }
        };
        $scope.setActiveTask = function (task) {
          if (task === $scope.activeTask) {
            return;
          }
          $scope.activeTask = task;
          return loadPdf(task);
        };
        $scope.activeTaskUrl = function () {
          return TaskFeedback.getTaskUrl($scope.activeTask);
        };
        $scope.activeTask = $scope.submittedTasks[0];
        loadPdf($scope.activeTask);
        $scope.statusData = function (task) {
          return {
            icon: statusIcons[task.status],
            label: statusLabels[task.status]
          };
        };
        $scope.activeStatusData = function () {
          return $scope.statusData($scope.activeTask);
        };
        return $scope.statusClass = function (status) {
          return _.trim(_.dasherize(status));
        };
      }
    ]
  };
});