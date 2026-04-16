from app.hello import hello


def test_hello():
  assert hello() == 'Hello from {{DEV_NAME}}'
