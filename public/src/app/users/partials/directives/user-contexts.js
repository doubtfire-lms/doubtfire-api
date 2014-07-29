angular.module('doubtfire.users.partials.contexts', []).directive('userListContext', function () {
  return {
    restrict: 'E',
    templateUrl: 'users/partials/templates/user-list-context.tpl.html',
    controller: [
      '$scope',
      '$modal',
      'User',
      function ($scope, $modal, User) {
        $scope.sortOrder = 'id';
        $scope.currentPage = 1;
        $scope.maxSize = 5;
        $scope.pageSize = 15;
        return $scope.showUserModal = function (user) {
          var userToShow;
          userToShow = user != null ? user : new User({});
          return $modal.open({
            templateUrl: 'users/partials/templates/user-modal-context.tpl.html',
            controller: 'UserModalCtrl',
            resolve: {
              user: function () {
                return userToShow;
              },
              isNew: function () {
                return user == null;
              },
              users: function () {
                return $scope.users;
              }
            }
          });
        };
      }
    ]
  };
}).directive('importExportContext', function () {
  return {
    restrict: 'E',
    templateUrl: 'users/partials/templates/import-export-context.tpl.html',
    controller: [
      '$scope',
      '$modal',
      'UserCSV',
      function ($scope, $modal, UserCSV) {
        $scope.fileUploader = UserCSV.fileUploader($scope);
        $scope.submitUpload = function () {
          return $scope.fileUploader.uploadAll();
        };
        return $scope.requestExport = function () {
          return UserCSV.downloadFile();
        };
      }
    ]
  };
});