document.addEventListener('DOMContentLoaded', () => {

  // Get all "navbar-burger" elements
  const $navbarBurgers = Array.prototype.slice.call(document.querySelectorAll('.navbar-burger'), 0);

  // Check if there are any navbar burgers
  if ($navbarBurgers.length > 0) {

    // Add a click event on each of them
    $navbarBurgers.forEach(el => {
      el.addEventListener('click', () => {

        // Get the target from the "data-target" attribute
        const target = el.dataset.target;
        const $target = document.getElementById(target);

        // Toggle the "is-active" class on both the "navbar-burger" and the "navbar-menu"
        el.classList.toggle('is-active');
        $target.classList.toggle('is-active');

      });
    });
  }
});

function safeHtml(text) {
  var decoder = document.createElement('textarea');
  decoder.textContent = text;
  return decoder.innerHTML;
}

Vue.prototype.$http = axios;
Vue.use(Buefy.default)
var app = new Vue({
  el: '#app',
  data: {
    loading: true,
    files: [],
    uploading: false,
    uploads: [],
    deleting: {},
    user: null,
  },
  created: function () {
    var vm = this;
    vm.fetchTokens();
    vm.get();
  },
  methods: {
    fetchTokens: function (event) {
      var vm = this;
      vm.$http
        .get('/api/tokens')
        .then(function (response) {
          vm.tokens = response.data;
          vm.user = {
            name: response.data.identity_token.name,
            picture: response.data.identity_token.picture,
          };
        }).catch(function (err) {
          console.log(err);
          vm.$toast.open({
            message: 'Failed to retrieve tokens',
            type: 'is-danger',
          });
        }).finally(function () {
        });
    },
    get: function (event) {
      var vm = this;
      vm.loading = true;
      vm.$http
        .get('/api/files')
        .then(function (response) {
          vm.files = response.data;
        }).catch(function (err) {
          console.log(err);
          vm.$toast.open({
            message: 'Failed to retrieve file list',
            type: 'is-danger',
          });
        }).finally(function () {
          vm.loading = false;
        });
    },
    upload: function (event) {
      var vm = this;
      console.log('uploading', vm.uploads);
      var formData = new FormData();
      vm.uploads.forEach(function (upload) {
        formData.append('file', upload, upload.name.replace(/\s/g, ''));
      });

      vm.uploading = true;
      vm.$http
        .post('/api/files',
          formData,
          {
            headers: {
              'Content-Type': 'multipart/form-data'
            }
          })
        .then(function (response) {
          vm.$toast.open({
            message: 'File uploaded!',
            type: 'is-success',
          });
          // reload the files
          vm.get();
        }).catch(function (err) {
          console.log(err);
          vm.$toast.open({
            message: 'Failed to upload file',
            type: 'is-danger',
          });
        }).finally(function () {
          vm.uploading = false;
        });
    },
    shareFile: function (id) {
      var vm = this;
      vm.$http
        .get(`/api/files/${id}/url`)
        .then(function (response) {
          if (response.status == 200) {
            vm.$dialog.alert({
              title: 'Share Link',
              message: `<textarea class="textarea is-small" readonly cols="75" rows="10">${response.data.url}</textarea><a href="${response.data.url}">Open link</a> <span class="has-text-grey">(Link expires after 5 minutes)</span>`,
              confirmText: 'Close',
            });
          }
        }).catch(function (err) {
          console.log(err);
          vm.$toast.open({
            message: 'Failed to build link',
            type: 'is-danger',
          });
        }).finally(function () {
        });
    },
    deleteFile: function (id, name) {
      var vm = this;
      vm.deleting[id] = true;
      vm.$forceUpdate();
      this.$dialog.confirm({
        title: 'Delete',
        message: `Really delete <b>${safeHtml(name)}</b>?`,
        cancelText: 'Cancel',
        confirmText: 'Delete',
        type: 'is-danger',
        onCancel: function () {
          delete vm.deleting[id];
          vm.$forceUpdate();
        },
        onConfirm: function () {
          vm.$http
            .delete(`/api/files/${id}`)
            .then(function (response) {
              vm.$toast.open({
                message: 'File deleted!',
                type: 'is-success',
              });
              // reload the table
              vm.get();
            }).catch(function (err) {
              console.log(err);
              vm.$toast.open({
                message: 'Failed to delete file',
                type: 'is-danger',
              });
            }).finally(function () {
              delete vm.deleting[id];
            });
        }
      });
    }
  }
});
