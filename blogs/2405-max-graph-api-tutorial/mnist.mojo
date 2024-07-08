import sys
from pathlib import Path
from python import Python as py
from max.graph import Graph, TensorType, ops
from max import engine
from extensibility import Tensor as TensorExt, empty_tensor
from max.tensor import Tensor, TensorShape, TensorSpec


def load_model_weights(use_relu6: Bool) -> PythonObject:
    np = py.import_module("numpy")
    if use_relu6:
        fin = py.evaluate('open("model_relu6_weights.npy", mode="rb")')
    else:
        fin = py.evaluate('open("model_weights.npy", mode="rb")')

    model_weights = np.load(fin, allow_pickle=True).item() # note this is of type PythonObject
    fin.close()
    print("python type of model_weights:", py.type(model_weights))
    for item in model_weights.items():
        print(item[0], item[1].shape, py.type(item[1]))

    return model_weights

@always_inline
fn numpy_data_pointer[type: DType](numpy_array: PythonObject) raises -> DTypePointer[type]:
    return numpy_array.__array_interface__["data"][0].unsafe_get_as_pointer[type]()

@always_inline
fn memcpy_from_numpy(array: PythonObject, tensor: Tensor) raises:
    var src = numpy_data_pointer[tensor.type](array)
    var dst = tensor._ptr
    var length = tensor.num_elements()
    memcpy(dst, src, length)

@always_inline
fn numpy_to_tensor[type: DType](array: PythonObject) raises -> Tensor[type]:
    var shape = List[Int]()
    var array_shape = array.shape
    for dim in array_shape:
        shape.append(dim.__index__())

    var out = Tensor[type](shape)
    memcpy_from_numpy(array, out)
    return out ^

def build_mnist_graph(
    fc1w: Tensor[DType.float32],
    fc1b: Tensor[DType.float32],
    fc2w: Tensor[DType.float32],
    fc2b: Tensor[DType.float32],
    use_relu6: Bool
    ) -> Graph:
    # Note: "batch" is a symbolic dim which is known ahead of time vs dynamic dim
    graph = Graph(TensorType(DType.float32, "batch", 28 * 28))
    # PyTorch linear is defined as: x W^T + b so we need to transpose the weights
    fc1 = (graph[0] @ ops.transpose(graph.constant(fc1w), 1, 0)) + graph.constant(fc1b)
    if use_relu6:
        relu = ops.custom["relu6"](fc1, fc1.type())
    else:
        relu = ops.relu(fc1)

    fc2 = (relu @ ops.transpose(graph.constant(fc2w), 1, 0)) + graph.constant(fc2b)
    out = ops.softmax(fc2) # adding explicit softmax for inference prob
    graph.output(out)
    graph.verify()
    return graph

def load_mnist_test_data() -> PythonObject:
    torchvision = py.import_module("torchvision")
    test_dataset = torchvision.datasets.MNIST(root='./data', train=False, transform=None, download=False)
    return test_dataset

def preprocess(image: PythonObject) -> PythonObject:
    transforms = py.import_module("torchvision.transforms")
    image_tensor = transforms.ToTensor()(image)
    image_tensor_normalized = transforms.Normalize((0.5,), (0.5,))(image_tensor)
    reshaped_image = image_tensor_normalized.reshape(1, 28 * 28).numpy()
    return reshaped_image

def main():
    args = sys.argv()
    if args[1] == "--use-relu6":
        use_relu6 = True
    else:
        use_relu6 = False

    weights_dict = load_model_weights(use_relu6)
    fc1w = numpy_to_tensor[DType.float32](weights_dict["fc1.weight"])
    fc1b = numpy_to_tensor[DType.float32](weights_dict["fc1.bias"])
    fc2w = numpy_to_tensor[DType.float32](weights_dict["fc2.weight"])
    fc2b = numpy_to_tensor[DType.float32](weights_dict["fc2.bias"])

    mnist_graph = build_mnist_graph(fc1w^, fc1b^, fc2w^, fc2b^, use_relu6)
    session = engine.InferenceSession()
    if use_relu6:
        model = session.load(mnist_graph, custom_ops_paths=Path("custom_ops.mojopkg"))
    else:
        model = session.load(mnist_graph)

    for name in model.get_model_input_names():
        print("input:", name[])

    for name in model.get_model_output_names():
        print("output:", name[])

    correct = 0
    total = 0
    # use batch size of 1 in this example
    test_dataset = load_mnist_test_data()
    for i in range(len(test_dataset)):
        item = test_dataset[i]
        image = item[0]
        label = item[1]

        preprocessed_image = preprocess(image)

        output = model.execute("input0", preprocessed_image)
        probs = output.get[DType.float32]("output0")

        predicted = probs.argmax(axis=1)

        label_ = Tensor[DType.index](TensorShape(1), int(label))
        correct += int(predicted == label_)
        total += 1

    print("Accuracy of the network on the 10000 test images:", 100 * correct / total, "%")
