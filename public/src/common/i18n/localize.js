/*
 * An AngularJS Localization Service
 *
 * Written by Jim Lavin
 * http://codingsmackdown.tv
 *
 */
angular.module('localization', []).factory('localize', [
  '$http',
  '$rootScope',
  '$window',
  '$filter',
  function ($http, $rootScope, $window, $filter) {
    var localize = {
        language: $window.navigator.userLanguage || $window.navigator.language,
        dictionary: [],
        resourceFileLoaded: false,
        successCallback: function (data) {
          // store the returned array in the dictionary
          localize.dictionary = data;
          // set the flag that the resource are loaded
          localize.resourceFileLoaded = true;
          // broadcast that the file has been loaded
          $rootScope.$broadcast('i18nReady');
        },
        setLanguage: function (value) {
          localize.language = value;
          localize.initLocalizedResources();
        },
        initLocalizedResources: function () {
          // build the url to retrieve the localized resource file
          var url = 'src/i18n/resources-locale_' + localize.language + '.js';
          // request the resource file
          $http({
            method: 'GET',
            url: url,
            cache: false
          }).success(localize.successCallback).error(function () {
            // the request failed set the url to the default resource file
            var url = 'src/i18n/resources-locale_default.js';
            // request the default resource file
            $http({
              method: 'GET',
              url: url,
              cache: false
            }).success(localize.successCallback);
          });
        },
        getLocalizedString: function (value) {
          // default the result to an empty string
          var result = '';
          // make sure the dictionary has valid data
          if (localize.dictionary !== [] && localize.dictionary.length > 0) {
            // use the filter service to only return those entries which match the value
            // and only take the first result
            var entry = $filter('filter')(localize.dictionary, function (element) {
                return element.key === value;
              })[0];
            // set the result
            result = entry.value;
          }
          // return the value to the call
          return result;
        }
      };
    // force the load of the resource file
    localize.initLocalizedResources();
    // return the local instance when called
    return localize;
  }
]).filter('i18n', [
  'localize',
  function (localize) {
    return function (input) {
      return localize.getLocalizedString(input);
    };
  }
]).directive('i18n', [
  'localize',
  function (localize) {
    var i18nDirective = {
        restrict: 'EAC',
        updateText: function (elm, token) {
          var values = token.split('|');
          if (values.length >= 1) {
            // construct the tag to insert into the element
            var tag = localize.getLocalizedString(values[0]);
            // update the element only if data was returned
            if (tag !== null && tag !== undefined && tag !== '') {
              if (values.length > 1) {
                for (var index = 1; index < values.length; index++) {
                  var target = '{' + (index - 1) + '}';
                  tag = tag.replace(target, values[index]);
                }
              }
              // insert the text into the element
              elm.text(tag);
            }
          }
        },
        link: function (scope, elm, attrs) {
          scope.$on('i18nReady', function () {
            i18nDirective.updateText(elm, attrs.i18n);
          });
          attrs.$observe('i18n', function (value) {
            i18nDirective.updateText(elm, attrs.i18n);
          });
        }
      };
    return i18nDirective;
  }
]).directive('i18nAttr', [
  'localize',
  function (localize) {
    var i18NAttrDirective = {
        restrict: 'EAC',
        updateText: function (elm, token) {
          var values = token.split('|');
          // construct the tag to insert into the element
          var tag = localize.getLocalizedString(values[0]);
          // update the element only if data was returned
          if (tag !== null && tag !== undefined && tag !== '') {
            if (values.length > 2) {
              for (var index = 2; index < values.length; index++) {
                var target = '{' + (index - 2) + '}';
                tag = tag.replace(target, values[index]);
              }
            }
            // insert the text into the element
            elm.attr(values[1], tag);
          }
        },
        link: function (scope, elm, attrs) {
          scope.$on('localizeResourcesUpdated', function () {
            i18NAttrDirective.updateText(elm, attrs.i18nAttr);
          });
          attrs.$observe('i18nAttr', function (value) {
            i18NAttrDirective.updateText(elm, value);
          });
        }
      };
    return i18NAttrDirective;
  }
]);