from flask import Flask, render_template, request, make_response, g
from redis import Redis
import os
import socket
import random
import json
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

option_a = os.getenv('OPTION_A', "Python")
option_b = os.getenv('OPTION_B', "Javascript")
hostname = socket.gethostname()

app = Flask(__name__)

REQUEST_COUNTER = Counter(
    'http_requests_total',
    'Total HTTP requests processed by the service',
    ['service', 'method', 'path', 'status']
)

def get_redis():
    if not hasattr(g, 'redis'):
        g.redis = Redis(host="redis", db=0, socket_timeout=5)
    return g.redis

@app.route("/", methods=['POST','GET'])
def hello():
    voter_id = request.cookies.get('voter_id')
    if not voter_id:
        voter_id = hex(random.getrandbits(64))[2:-1]

    vote = None

    if request.method == 'POST':
        redis = get_redis()
        vote = request.form['vote']
        data = json.dumps({'voter_id': voter_id, 'vote': vote})
        redis.rpush('votes', data)

    resp = make_response(render_template(
        'index.html',
        option_a=option_a,
        option_b=option_b,
        hostname=hostname,
        vote=vote,
    ))
    resp.set_cookie('voter_id', voter_id)
    return resp


@app.route('/metrics', methods=['GET'])
def metrics():
    return app.response_class(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


@app.after_request
def count_http_requests(response):
    REQUEST_COUNTER.labels(
        service='vote',
        method=request.method,
        path=request.path,
        status=str(response.status_code),
    ).inc()
    return response


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80, debug=True, threaded=True)
