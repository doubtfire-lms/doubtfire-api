angular.module('doubtfire.users', ['doubtfire.users.partials']).config([
  '$stateProvider',
  function ($stateProvider) {
    return $stateProvider.state('admin/users#index', {
      url: '/admin/users',
      views: {
        main: {
          controller: 'AdminUsersCtrl',
          templateUrl: 'users/admin.tpl.html'
        },
        header: {
          controller: 'BasicHeaderCtrl',
          templateUrl: 'common/header.tpl.html'
        }
      },
      data: {
        pageTitle: '_Users Administration_',
        roleWhitelist: [
          'Admin',
          'Convenor'
        ]
      }
    });
  }
]).controller('AdminUsersCtrl', [
  '$scope',
  '$state',
  '$stateParams',
  '$modal',
  'User',
  function ($scope, $state, $stateParams, $modal, User) {
    return $scope.users = User.query();
  }
]);