const AssetImport = {
  mounted() {
    const { assetFiles } = this.el.dataset;
    const headEl = document.getElementsByTagName("head")[0];
    const bodyEl = document.getElementsByTagName("body")[0];
    assetFiles.split(" ").forEach(fileName => {
      if (fileName.substr(-4) === '.css') {
        if (headEl.querySelectorAll(`link[rel="stylesheet"][href="${fileName}"]`).length) {
          return;
        }
        const el = document.createElement("link");
        el.rel = "stylesheet";
        el.type = "text/css";
        el.href = fileName;
        headEl.appendChild(el)
      }
      else if (fileName.substr(-3) === '.js') {
        if (document.querySelectorAll(`script[src="${fileName}"]`).length) {
          return;
        }
        const el = document.createElement('script');;
        el.src = fileName;
        bodyEl.appendChild(el);
      }
    });
  }
};

function ready(callback){
  // in case the document is already rendered
  if (document.readyState!='loading') callback();
  // modern browsers
  else if (document.addEventListener) document.addEventListener('DOMContentLoaded', callback);
  // IE <= 8
  else document.attachEvent('onreadystatechange', function(){
      if (document.readyState=='complete') callback();
  });
}

const onloadCallbacks = {};
const addOnloadCallback = (hook, callback) => {
  if (onloadCallbacks[hook] === null) {
    callback();
  }
  else {
    if (!onloadCallbacks[hook]) {
      onloadCallbacks[hook] = [];
    }
    onloadCallbacks[hook].push(callback);
  }
}

const AssetHook = {
  mounted() {
    const { assets, hook } = this.el.dataset;
    const headEl = document.getElementsByTagName("head")[0];
    const bodyEl = document.getElementsByTagName("body")[0];
    const assetFiles = assets.split(" ");
    this.el.loadingAssets = assetFiles.slice(0);
    
    const onload = (fileName) => {
      const index = this.el.loadingAssets.indexOf(fileName);
      if (index !== -1) {
        this.el.loadingAssets.splice(index, 1);
        if (!this.el.loadingAssets.length) {
          if (onloadCallbacks[hook]) {
            onloadCallbacks[hook].forEach(x => x());
          }
          onloadCallbacks[hook] = null;
        }
      }
    };

    assetFiles.forEach(fileName => {
      if (fileName.substr(-4) === '.css') {
        const existingEl = headEl.querySelectorAll(`link[rel="stylesheet"][href="${fileName}"]`)[0];
        if (existingEl) {
          if (!existingEl.onload) {
            ready(() => {
              onload(fileName);
            });
          }
          return;
        }
        const el = document.createElement("link");
        el.rel = "stylesheet";
        el.type = "text/css";
        el.href = fileName;
        el.onload = () => onload(fileName);
        headEl.appendChild(el)
      }
      else if (fileName.substr(-3) === '.js') {
        const existingEl = document.querySelectorAll(`script[src="${fileName}"]`)[0]
        if (existingEl) {
          if (!existingEl.onload) {
            ready(() => {
              onload(fileName)
            });
          }
          return;
        }
        const el = document.createElement('script');;
        el.src = fileName;
        el.onload = () => onload(fileName);
        bodyEl.appendChild(el);
      }
    });
    addOnloadCallback(hook, () => {
      const targetHook = this.__view.liveSocket.hooks[hook]
      if (targetHook && targetHook.mounted) {
        targetHook.mounted.apply(this);
      }
    });
  },

  updated() {
    const { hook } = this.el.dataset;
    addOnloadCallback(hook, () => {
      const targetHook = this.__view.liveSocket.hooks[hook]
      if (targetHook && targetHook.updated) {
        targetHook.updated.apply(this);
      }
    });
  },

  destroyed() {
    const { hook } = this.el.dataset;
    addOnloadCallback(hook, () => {
      const targetHook = this.__view.liveSocket.hooks[hook]
      if (targetHook && targetHook.destroyed) {
        targetHook.destroyed.apply(this);
      }
    });
  }
};

export {AssetImport, AssetHook};
export default AssetImport;