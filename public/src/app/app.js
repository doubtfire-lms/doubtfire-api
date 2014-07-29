var statusIcons, statusKeys, statusLabels;
statusKeys = [
  'not_submitted',
  'fix_and_include',
  'redo',
  'need_help',
  'working_on_it',
  'fix_and_resubmit',
  'ready_to_mark',
  'discuss',
  'complete'
];
statusLabels = {
  'ready_to_mark': 'Ready to Mark',
  'not_submitted': 'Not Started',
  'working_on_it': 'Working On It',
  'need_help': 'Need Help',
  'redo': 'Redo',
  'fix_and_include': 'Fix and Include',
  'fix_and_resubmit': 'Resubmit',
  'discuss': 'Discuss',
  'complete': 'Complete'
};
statusIcons = {
  'ready_to_mark': 'fa fa-thumbs-o-up',
  'not_submitted': 'fa fa-times',
  'working_on_it': 'fa fa-bolt',
  'need_help': 'fa fa-question-circle',
  'redo': 'fa fa-refresh',
  'fix_and_include': 'fa fa-stop',
  'fix_and_resubmit': 'fa fa-wrench',
  'discuss': 'fa fa-comment',
  'complete': 'fa fa-check-circle-o'
};
angular.module('doubtfire', [
  'ngCookies',
  'templates-app',
  'templates-common',
  'localization',
  'ui.router',
  'ui.bootstrap',
  'nvd3ChartDirectives',
  'angularFileUpload',
  'doubtfire.api',
  'doubtfire.errors',
  'doubtfire.sessions',
  'doubtfire.header',
  'doubtfire.home',
  'doubtfire.units',
  'doubtfire.tasks',
  'doubtfire.projects',
  'doubtfire.users'
]).config([
  '$urlRouterProvider',
  '$httpProvider',
  function ($urlRouterProvider, $httpProvider) {
    $urlRouterProvider.otherwise('/not_found');
    $urlRouterProvider.when('', '/');
    return $urlRouterProvider.when('/', '/home');
  }
]).run([
  '$rootScope',
  '$state',
  '$filter',
  'auth',
  function ($rootScope, $state, $filter, auth) {
    var handleUnauthorised;
    handleUnauthorised = function () {
      if (auth.isAuthenticated()) {
        return $state.go('unauthorised');
      } else if ($state.current.name !== 'sign_in') {
        return $state.go('sign_in');
      }
    };
    $rootScope.$on('$stateChangeStart', function (evt, toState) {
      if (!auth.isAuthorised(toState.data.roleWhitelist)) {
        evt.preventDefault();
        return handleUnauthorised();
      }
    });
    $rootScope.$on('unauthorisedRequestIntercepted', handleUnauthorised);
    return _.mixin(_.string.exports());
  }
]).controller('AppCtrl', [
  '$rootScope',
  '$state',
  '$document',
  '$filter',
  function ($rootScope, $state, $document, $filter) {
    var setPageTitle, suffix;
    suffix = $document.prop('title');
    return setPageTitle = function (state) {
      return $document.prop('title', $filter('i18n')(state.data.pageTitle) + ' | ' + suffix);
    };
  }
]);