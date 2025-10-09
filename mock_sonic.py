from flask import Flask, jsonify, request

app = Flask(__name__)

# GET example: telemetry / RESTCONF data
@app.route('/restconf/data', methods=['GET'])
def get_data():
    return jsonify({
        'hostname': 'mock-sonic',
        'interfaces': [{'name': 'Ethernet0', 'admin': 'up'}],
        'topology': [{'neighbor': 'leaf1', 'port': 'Ethernet0'}]
    })

# POST example: config simulation
@app.route('/restconf/config', methods=['POST'])
def post_config():
    data = request.get_json()
    return jsonify({'status': 'ok', 'received': data}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
