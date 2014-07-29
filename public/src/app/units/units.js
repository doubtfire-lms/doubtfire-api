angular.module('doubtfire.units', ['doubtfire.units.partials']).config([
  '$stateProvider',
  function ($stateProvider) {
    return $stateProvider.state('units#show', {
      url: '/units?unitRole',
      views: {
        main: {
          controller: 'UnitsShowCtrl',
          templateUrl: 'units/show.tpl.html'
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
    }).state('admin/units#index', {
      url: '/admin/units',
      views: {
        main: {
          controller: 'AdminUnitsCtrl',
          templateUrl: 'units/admin.tpl.html'
        },
        header: {
          controller: 'BasicHeaderCtrl',
          templateUrl: 'common/header.tpl.html'
        }
      },
      data: {
        pageTitle: '_Unit Administration_',
        roleWhitelist: [
          'Admin',
          'Convenor'
        ]
      }
    }).state('admin/units#edit', {
      url: '/admin/units/:unitId',
      views: {
        main: {
          controller: 'EditUnitCtrl',
          templateUrl: 'units/unit.tpl.html'
        },
        header: {
          controller: 'BasicHeaderCtrl',
          templateUrl: 'common/header.tpl.html'
        }
      },
      data: {
        pageTitle: '_Unit Administration_',
        roleWhitelist: [
          'Admin',
          'Convenor'
        ]
      }
    });
  }
]).controller('UnitsShowCtrl', [
  '$scope',
  '$state',
  '$stateParams',
  'Unit',
  'UnitRole',
  'headerService',
  'alertService',
  function ($scope, $state, $stateParams, Unit, UnitRole, headerService, alertService) {
    $scope.unitLoaded = false;
    UnitRole.get({ id: $state.params.unitRole }, function (unitRole) {
      var other_role, rolesMenu, _i, _len, _ref;
      $scope.unitRole = unitRole;
      headerService.clearMenus();
      if (unitRole) {
        if (unitRole.other_roles.length > 0) {
          rolesMenu = {
            name: '' + unitRole.role + ' View',
            links: [],
            icon: 'globe'
          };
          rolesMenu.links.push({
            'class': 'active',
            url: '#/units?unitRole=' + unitRole.id,
            name: unitRole.role
          });
          _ref = unitRole.other_roles;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            other_role = _ref[_i];
            rolesMenu.links.push({
              'class': '',
              url: '#/units?unitRole=' + other_role.id,
              name: other_role.role
            });
          }
          headerService.setMenus([rolesMenu]);
        }
      }
      if (unitRole) {
        return Unit.get({ id: unitRole.unit_id }, function (unit) {
          $scope.unit = unit;
          return $scope.unitLoaded = true;
        });
      }
    });
    $scope.taskDef = function (taskDefId) {
      return _.where($scope.unit.task_definitions, { id: taskDefId });
    };
    $scope.tutorialFromId = function (tuteId) {
      return _.where($scope.unit.tutorials, { id: tuteId });
    };
    return $scope.taskCount = function () {
      return $scope.unit.task_definitions.length;
    };
  }
]).controller('AdminUnitsCtrl', [
  '$scope',
  '$state',
  '$modal',
  'Unit',
  function ($scope, $state, $modal, Unit) {
    $scope.units = Unit.query({});
    $scope.showUnit = function (unit) {
      var unitToShow;
      return unitToShow = unit != null ? $state.transitionTo('admin/units#edit', { unitId: unit.id }) : void 0;
    };
    return $scope.createUnit = function () {
      return $modal.open({
        templateUrl: 'units/partials/templates/unit-create-modal.tpl.html',
        controller: 'AddUnitCtrl',
        resolve: {
          units: function () {
            return $scope.units;
          }
        }
      });
    };
  }
]).controller('EditUnitCtrl', [
  '$scope',
  '$state',
  '$stateParams',
  'Unit',
  'UnitRole',
  'headerService',
  'alertService',
  'Convenor',
  'Tutor',
  'Students',
  function ($scope, $state, $stateParams, Unit, UnitRole, headerService, alertService, Convenor, Tutor, Students) {
    Convenor.query().$promise.then(function (convenors) {
      return Tutor.query().$promise.then(function (tutors) {
        var staff;
        staff = _.union(convenors, tutors);
        staff = _.map(staff, function (convenor) {
          return {
            id: convenor.id,
            full_name: convenor.first_name + ' ' + convenor.last_name
          };
        });
        staff = _.uniq(staff, function (item) {
          return item.id;
        });
        return $scope.staff = staff;
      });
    });
    return Unit.get({ id: $state.params.unitId }, function (unit) {
      $scope.unit = unit;
      $scope.currentStaff = $scope.unit.staff;
      $scope.tutorialFromId = function (tuteId) {
        return _.where($scope.unit.tutorials, { id: tuteId });
      };
      return Students.query({ unit_id: $scope.unit.id }, function (students) {
        return $scope.unit.students = students.map(function (student) {
          student.tutorial = $scope.tutorialFromId(student.tute)[0].abbreviation;
          student.first_name = student.name.split(' ')[0];
          student.last_name = student.name.split(' ').pop();
          student.email = student.student_email;
          student.username = student.student_id;
          return student;
        });
      });
    });
  }
]).controller('AddUnitCtrl', [
  '$scope',
  '$modalInstance',
  'alertService',
  'units',
  'Unit',
  function ($scope, $modalInstance, alertService, units, Unit) {
    $scope.unit = new Unit({
      id: -1,
      active: true,
      code: 'COS????'
    });
    return $scope.saveSuccess = function (unit) {
      alertService.add('success', 'Unit created.', 2000);
      $modalInstance.close();
      return units.push(unit);
    };
  }
]);