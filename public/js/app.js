(function($) {
    $(function() {

        var App = {

            /**
             * setup for all pages.
             */
            init: function() {

                this.currentLocale();

                if (this.locale == 'ar')
                  $('.button-collapse').sideNav({ edge: "right" });
                else
                  $('.button-collapse').sideNav();

                $('.parallax').parallax();
                $('select').material_select();
                $('.tooltipped').tooltip({delay: 50});
                this.scan();
            },

            /**
             * page specific javascript
             */

            scan: function() {
                var form = $('#scan-form');
                var fileUploadInput = $('#document');
                var nextButton = $('#next-button');

                if (form.size() == 0 || fileUploadInput.size() == 0)
                  return;

                var uploadMsg = this.getMsg('uploading');
                nextButton.click(function(e){
                  e.preventDefault();
                  if (!$(this).hasClass('disabled') && fileUploadInput.get(0).files.length > 0){
                    form.submit();
                    nextButton.addClass('disabled');
                    Materialize.toast(uploadMsg, 8000)
                  }
                });

                // validate upload size.
                var errorMsg = this.getMsg('fileSize');

                fileUploadInput.bind('change', function() {
                    var size_in_megabytes = this.files[0].size / 1024 / 1024;

                    if (size_in_megabytes > 10) {
                        nextButton.addClass('disabled');
                        var elm = '<p class="center red-text lighten-2 size-error">'+ errorMsg +'</p>';
                        if ($('p.size-error').size() == 0)
                          fileUploadInput.parent().parent().append(elm);
                    } else {
                      nextButton.removeClass('disabled');
                      var errorP = $('p.size-error');
                      if (errorP.size() > 0)
                        errorP.remove();
                    }
                });
            },

            /**
             * Helpers
             */
            // get the current language or :en fallback.
            currentLocale: function() {
              var locales = ['ar', 'en'];

              var l = $(location).attr('href').split('/')[3];
              if (locales.indexOf(l) != -1)
                this.locale = l;
              else
                this.locale = 'en';
            },

            // simple i18n string and error messages store.
            getMsg: function(name) {
              this.store = this.store || {
                'en': {
                  'fileSize': "Maximum file size is 10MB. Please choose a smaller file.",
                  'uploading': "Excellent! uploading's started .."
                },
                'ar': {
                  'fileSize': 'الحجم الأقصى للملف ١٠ ميجابايت. من فضلك اختر ملفاً أصغر.',
                  'uploading': 'ممتاز ! جاري الرفع'
                },
              };

              return this.store[this.locale][name];
            },
        };

        App.init();

    }); // end of document ready
})(jQuery); // end of jQuery name space
