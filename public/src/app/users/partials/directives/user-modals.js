angular.module('doubtfire.users.partials.modals', []).controller('UserModalCtrl', [
  '$scope',
  '$modalInstance',
  'alertService',
  'currentUser',
  'User',
  'user',
  'users',
  'isNew',
  function ($scope, $modalInstance, alertService, currentUser, User, user, users, isNew) {
    $scope.user = user;
    $scope.users = users;
    $scope.currentUser = currentUser;
    $scope.isNew = isNew;
    $scope.modalState = {};
    return $scope.saveUser = function () {
      if ($scope.isNew) {
        return User.create({ user: $scope.user }).$promise.then(function (response) {
          $modalInstance.close(response);
          if ($scope.users) {
            return $scope.users.push(response);
          }
        }, function (response) {
          if (response.data.error != null) {
            return alertService.add('danger', 'Error: ' + response.data.error, 2000);
          }
        });
      } else {
        return User.update({
          id: $scope.user.id,
          user: $scope.user
        }).$promise.then(function (response) {
          $modalInstance.close(response);
          return user.name = user.first_name + ' ' + user.last_name;
        }, function (response) {
          if (response.data.error != null) {
            return alertService.add('danger', 'Error: ' + response.data.error, 2000);
          }
        });
      }
    };
  }
]);