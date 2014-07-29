angular.module('doubtfire.header', ['doubtfire.units.partials.modals']).factory('headerService', [
  '$rootScope',
  function ($rootScope) {
    $rootScope.header_menu_data = [];
    return {
      menus: function () {
        return $rootScope.header_menu_data;
      },
      clearMenus: function () {
        return $rootScope.header_menu_data.length = 0;
      },
      setMenus: function (new_menus) {
        var menu, _i, _len, _results;
        $rootScope.header_menu_data.length = 0;
        _results = [];
        for (_i = 0, _len = new_menus.length; _i < _len; _i++) {
          menu = new_menus[_i];
          _results.push($rootScope.header_menu_data.push(menu));
        }
        return _results;
      },
      push: function (new_menu) {
        var menu;
        if (function () {
            var _i, _len, _ref, _results;
            _ref = $rootScope.header_menu_data;
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              menu = _ref[_i];
              if (menu.name === new_menu.name) {
                _results.push(menu);
              }
            }
            return _results;
          }().length === 0) {
          return $rootScope.header_menu_data.push(new_menu);
        }
      }
    };
  }
]).factory('alertService', [
  '$rootScope',
  '$timeout',
  '$sce',
  function ($rootScope, $timeout, $sce) {
    var alertSvc;
    $rootScope.alerts = [];
    return alertSvc = {
      add: function (type, msg, timeout) {
        $rootScope.alerts.push({
          type: type,
          msg: $sce.trustAsHtml(msg),
          close: function () {
            return alertSvc.closeAlert(this);
          }
        });
        if (timeout) {
          return $timeout(function () {
            return alertSvc.closeAlert(this);
          }, timeout);
        }
      },
      closeAlert: function (alert) {
        return this.closeAlertIdx($rootScope.alerts.indexOf(alert));
      },
      closeAlertIdx: function (index) {
        return $rootScope.alerts.splice(index, 1);
      },
      clear: function () {
        return $rootScope.alerts = [];
      }
    };
  }
]).controller('BasicHeaderCtrl', [
  '$scope',
  '$state',
  '$modal',
  'currentUser',
  'headerService',
  'UnitRole',
  'User',
  'Project',
  function ($scope, $state, $modal, currentUser, headerService, UnitRole, User, Project) {
    $scope.menus = headerService.menus();
    $scope.currentUser = currentUser.profile;
    $scope.unitRoles = UnitRole.query();
    $scope.projects = Project.query();
    $scope.isUniqueUnitRole = function (unit) {
      var item, units;
      units = function () {
        var _i, _len, _ref, _results;
        _ref = $scope.unitRoles;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          if (item.unit_id === unit.unit_id) {
            _results.push(item);
          }
        }
        return _results;
      }();
      return units.length === 1 || unit.role === 'Tutor';
    };
    return $scope.openUserSettings = function () {
      return $modal.open({
        templateUrl: 'users/partials/templates/user-modal-context.tpl.html',
        controller: 'UserModalCtrl',
        resolve: {
          user: function () {
            return $scope.currentUser;
          },
          isNew: function () {
            return false;
          },
          users: function () {
            return false;
          }
        }
      });
    };
  }
]).controller('BasicSidebarCtrl', [
  '$scope',
  '$state',
  'currentUser',
  'headerService',
  'UnitRole',
  'Project',
  function ($scope, $state, currentUser, headerService, UnitRole, Project) {
    $scope.unitRoles = UnitRole.query();
    $scope.projects = Project.query();
    $scope.isTutor = function (userRole) {
      return userRole.role === 'Tutor';
    };
    return $scope.isConvenor = function (userRole) {
      return userRole.role === 'Convenor';
    };
  }
]);