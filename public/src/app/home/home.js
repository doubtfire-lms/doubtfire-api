angular.module('doubtfire.home', []).config([
  '$stateProvider',
  function ($stateProvider) {
    return $stateProvider.state('home', {
      url: '/home',
      views: {
        main: {
          controller: 'HomeCtrl',
          templateUrl: 'home/index.tpl.html'
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
]).controller('HomeCtrl', [
  '$scope',
  '$state',
  '$modal',
  'User',
  'UnitRole',
  'Project',
  'headerService',
  'currentUser',
  function ($scope, $state, $modal, User, UnitRole, Project, headerService, currentUser) {
    $scope.unitRoles = UnitRole.query();
    $scope.projects = Project.query();
    headerService.clearMenus();
    if (currentUser.profile.name.toLowerCase() === 'first name surname') {
      $modal.open({
        templateUrl: 'users/partials/templates/user-modal-context.tpl.html',
        controller: 'UserModalCtrl',
        resolve: {
          user: function () {
            return currentUser.profile;
          },
          isNew: function () {
            return false;
          },
          users: function () {
            return false;
          }
        }
      });
    }
    $scope.isTutor = function (unitRole) {
      return unitRole.role === 'Tutor';
    };
    return $scope.isConvenor = function (unitRole) {
      return unitRole.role === 'Convenor';
    };
  }
]);