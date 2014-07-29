var __indexOf = [].indexOf || function (item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (i in this && this[i] === item)
        return i;
    }
    return -1;
  };
angular.module('doubtfire.sessions', [
  'ngCookies',
  'ui.router',
  'doubtfire.api'
]).constant('authRoles', [
  'anon',
  'Student',
  'Tutor',
  'Convenor',
  'Admin'
]).constant('currentUser', {
  id: 0,
  role: 'anon',
  profile: {
    name: 'Anonymous',
    nickname: 'anon'
  }
}).constant('userCookieName', 'doubtfire_user').directive('ifRole', [
  'auth',
  function (auth) {
    return {
      restrict: 'A',
      link: function (scope, element, attrs) {
        var roleWhitelist;
        roleWhitelist = _.string.words(attrs.ifRole);
        if (!auth.isAuthorised(roleWhitelist)) {
          return element.remove();
        }
      }
    };
  }
]).config([
  '$stateProvider',
  function ($stateProvider) {
    return $stateProvider.state('sign_in', {
      url: '/sign_in',
      views: {
        main: {
          controller: 'SignInCtrl',
          templateUrl: 'sessions/sign_in.tpl.html'
        }
      },
      data: { pageTitle: '_Sign In_' }
    }).state('sign_out', {
      url: '/sign_out',
      views: {
        main: {
          controller: 'SignOutCtrl',
          templateUrl: 'sessions/sign_out.tpl.html'
        }
      },
      data: { pageTitle: '_Sign Out_' }
    });
  }
]).config([
  '$httpProvider',
  function ($httpProvider) {
    return $httpProvider.interceptors.push(function ($q, $rootScope, api, currentUser) {
      return {
        request: function (config) {
          if (_.string.startsWith(config.url, api) && currentUser.authenticationToken != null) {
            if (!_.has(config, 'params')) {
              config.params = {};
            }
            config.params.auth_token = currentUser.authenticationToken;
          }
          return config || $q.when(config);
        },
        responseError: function (response) {
          if (_.string.startsWith(response.config.url, api) && response.status === 401) {
            $rootScope.$broadcast('unauthorisedRequestIntercepted');
          }
          return $q.reject(response);
        }
      };
    });
  }
]).factory('auth', [
  '$http',
  '$cookieStore',
  'userCookieName',
  'currentUser',
  'authRoles',
  function ($http, $cookieStore, userCookieName, currentUser, authRoles) {
    var defaultAnonymousUser, isValidRoleWhitelist, tryChangeUser;
    tryChangeUser = function (user) {
      var prop, _ref;
      if (user != null && (_ref = user.role, __indexOf.call(authRoles, _ref) >= 0)) {
        for (prop in currentUser) {
          delete currentUser[prop];
        }
        _.extend(currentUser, user);
        $cookieStore.put(userCookieName, currentUser);
        return true;
      } else {
        return false;
      }
    };
    isValidRoleWhitelist = function (roleWhitelist) {
      return _.difference(roleWhitelist, authRoles).length === 0;
    };
    defaultAnonymousUser = _.clone(currentUser);
    tryChangeUser($cookieStore.get(userCookieName));
    return {
      isAuthenticated: function () {
        return !_.isEqual(currentUser, defaultAnonymousUser);
      },
      isAuthorised: function (roleWhitelist, role) {
        if (role == null) {
          role = currentUser.role;
        }
        return roleWhitelist == null || isValidRoleWhitelist(roleWhitelist) && __indexOf.call(roleWhitelist, role) >= 0;
      },
      signIn: function (authenticationUrl, userCredentials, success, error) {
        if (success == null) {
          success = function () {
          };
        }
        if (error == null) {
          error = function () {
          };
        }
        return $http.post(authenticationUrl, userCredentials).success(function (response) {
          var user;
          user = {
            id: response.user.id,
            authenticationToken: response.auth_token,
            role: _.string.camelize(response.user.system_role),
            profile: response.user
          };
          if (tryChangeUser(user)) {
            return success();
          } else {
            return error();
          }
        }).error(error);
      },
      signOut: function (authenticationUrl) {
        $http['delete'](authenticationUrl);
        return tryChangeUser(defaultAnonymousUser);
      }
    };
  }
]).controller('SignInCtrl', [
  '$scope',
  '$state',
  '$timeout',
  '$modal',
  'currentUser',
  'auth',
  'api',
  'alertService',
  function ($scope, $state, $timeout, $modal, currentUser, auth, api, alertService) {
    var stateAfterSignIn;
    stateAfterSignIn = 'home';
    if (auth.isAuthenticated()) {
      return $state.go(stateAfterSignIn);
    } else {
      return $scope.signIn = function () {
        return auth.signIn(api + '/auth', {
          username: $scope.session.username,
          password: $scope.session.password
        }, function () {
          return $state.go(stateAfterSignIn);
        }, function (response) {
          $scope.session.password = '';
          return alertService.add('danger', 'Login failed: ' + response.error, 5000);
        });
      };
    }
  }
]).controller('SignOutCtrl', [
  '$state',
  '$timeout',
  'auth',
  'api',
  'currentUser',
  function ($state, $timeout, auth, api, currentUser) {
    if (auth.signOut(api + '/auth/' + currentUser.authenticationToken + '.json')) {
      $timeout(function () {
        return $state.go('sign_in');
      }, 750);
    }
    return this;
  }
]);