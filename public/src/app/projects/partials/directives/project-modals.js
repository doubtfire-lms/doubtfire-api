angular.module('doubtfire.projects.partials.modals', []).controller('ProjectLabSelectModalCtrl', [
  '$scope',
  '$modalInstance',
  'Users',
  'unit',
  function ($scope, $modalInstance, Users, unit) {
    $scope.unit = unit;
    /*
  ## TODO... (this modal code was just copied and pasted from the units one... will need to fix...)
  */
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
]);