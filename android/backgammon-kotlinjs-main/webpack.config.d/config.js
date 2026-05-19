const path = require('path');

// resources for the site
config.module.rules.push(
    {
        test: /\.(png|svg|jpg|css)$/,
        type: 'asset/resource'
    }
);

// resource files for the worker (onnx models)
config.module.rules.push(
    {
        test: /\.(onnx)$/,
        type: 'asset/resource'
    }
);

// turn off the 244k file limit warning
config.performance =  {
   hints: false,
   maxEntrypointSize: 512000,
   maxAssetSize: 512000
}
