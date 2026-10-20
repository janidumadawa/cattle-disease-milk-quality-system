def make_gradcam_v2(image_path):
    original_bgr = cv2.imread(image_path)
    if original_bgr is None:
        raise ValueError(f"Image not found: {image_path}")

    original = cv2.cvtColor(original_bgr, cv2.COLOR_BGR2RGB)
    h, w = original.shape[:2]

    resized = cv2.resize(original, (224, 224))
    x = tf.convert_to_tensor(
        resized.astype(np.float32)[None, ...]
    )

    # Find nested backbone, if present
    backbone = None
    for layer in model.layers:
        if isinstance(layer, tf.keras.Model):
            backbone = layer
            break

    if backbone is None:
        raise ValueError(
            "No nested backbone found. Run Step 1 and inspect model layers."
        )

    conv_layer = None
    for layer in reversed(backbone.layers):
        if isinstance(layer, tf.keras.layers.Conv2D):
            conv_layer = layer
            break

    if conv_layer is None:
        raise ValueError("No Conv2D layer found in backbone.")

    print("Backbone:", backbone.name)
    print("Target convolution:", conv_layer.name)

    # Build a feature extractor from the backbone input
    feature_model = tf.keras.Model(
        inputs=backbone.inputs,
        outputs=[conv_layer.output, backbone.output]
    )

    with tf.GradientTape() as tape:
        features, backbone_output = feature_model(x, training=False)

        # This method assumes the backbone feeds directly into the classifier.
        # Verify the model structure if dimensions do not match.
        z = backbone_output

        # Replay layers after the backbone to obtain class scores.
        passed_backbone = False
        for layer in model.layers:
            if layer is backbone:
                passed_backbone = True
                continue
            if passed_backbone:
                z = layer(z, training=False)

        predictions = z
        class_idx = tf.argmax(predictions[0])
        score = predictions[:, class_idx]

    grads = tape.gradient(score, features)
    if grads is None:
        raise ValueError(
            "Gradients are unavailable for this layer. "
            "We need the exact backbone/layer structure from Step 1."
        )

    weights = tf.reduce_mean(grads, axis=(1, 2))
    cam = tf.reduce_sum(
        features[0] * weights[0][None, None, :],
        axis=-1
    )
    cam = tf.nn.relu(cam)
    cam = cam / (tf.reduce_max(cam) + 1e-8)
    cam = cam.numpy()

    heatmap = cv2.resize(cam, (w, h))
    colored = cv2.applyColorMap(
        np.uint8(255 * heatmap), cv2.COLORMAP_JET
    )
    colored = cv2.cvtColor(colored, cv2.COLOR_BGR2RGB)

    overlay = cv2.addWeighted(original, 0.6, colored, 0.4, 0)

    idx = int(class_idx.numpy())
    print("Predicted class:", CLASS_NAMES[idx])
    print("Model score:", float(predictions[0, idx].numpy()))

    plt.figure(figsize=(15, 5))
    plt.subplot(1, 3, 1)
    plt.imshow(original)
    plt.title("Original")
    plt.axis("off")

    plt.subplot(1, 3, 2)
    plt.imshow(heatmap, cmap="jet")
    plt.title("Grad-CAM")
    plt.axis("off")

    plt.subplot(1, 3, 3)
    plt.imshow(overlay)
    plt.title("Highlighted area")
    plt.axis("off")
    plt.show()

    return heatmap, overlay
