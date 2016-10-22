/*global jQuery*/

jQuery.fn.legacyAlertWidget = function (propertyStorage, propertyName, tagElement, alertController) {
	'use strict';
	return jQuery.each(this, function () {
		var element = jQuery(this),
			alertId;
		element.detach();
		if (propertyStorage.getItem(propertyName)) {
			return;
		}
		element.find('[data-mm-role="legacy-alert-hide"]').click(function () {
			propertyStorage.setItem(propertyName, true);
			if (alertId) {
				alertController.hide(alertId);
			}
		});
		alertId = alertController.show(element, 'info');
	});
};
