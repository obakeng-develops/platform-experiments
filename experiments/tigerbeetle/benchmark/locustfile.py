import os
import time
import uuid

import requests
from locust import HttpUser, constant, events, task


UTILITY_COUNT = int(os.getenv("UTILITY_COUNT", "1"))
METER_COUNT = int(os.getenv("METER_COUNT", "1000"))
BATCH_SIZE = int(os.getenv("BATCH_SIZE", "10"))
NAMESPACE = uuid.UUID("fa9986a5-3b6e-48f8-8654-cdd1b14c2252")


def stable_id(kind, number):
    return str(uuid.uuid5(NAMESPACE, f"{kind}:{number}"))


def post(session, path, payload):
    response = session.post(f"{HttpUser.host}{path}", json=payload, timeout=60)
    if response.status_code not in (200, 201):
        raise RuntimeError(f"seed failed: {response.status_code} {response.text}")


def wait_until_ready(session):
    for _ in range(60):
        try:
            if session.get(f"{HttpUser.host}/up", timeout=2).status_code == 200:
                return
        except requests.RequestException:
            pass
        time.sleep(1)
    raise RuntimeError("API did not become ready within 60 seconds")


@events.test_start.add_listener
def seed(environment, **_kwargs):
    HttpUser.host = environment.host
    session = requests.Session()
    wait_until_ready(session)
    for utility_number in range(UTILITY_COUNT):
        post(session, "/utilities", {"utility": {
            "id": stable_id("utility", utility_number),
            "name": f"Utility {utility_number}",
            "tariff_micros_per_wh": 300,
        }})

    for meter_number in range(METER_COUNT):
        meter_id = stable_id("meter", meter_number)
        post(session, "/meters", {"meter": {
            "id": meter_id,
            "utility_id": stable_id("utility", meter_number % UTILITY_COUNT),
            "reference": f"meter-{meter_number}",
        }})
        post(session, "/top_ups", {"top_up": {
            "id": stable_id("top-up", meter_number),
            "meter_id": meter_id,
            "amount_micros": 10**15,
        }})


class MeterUser(HttpUser):
    wait_time = constant(0)

    @task
    def submit_readings(self):
        readings = []
        for _ in range(BATCH_SIZE):
            meter_number = int.from_bytes(os.urandom(4), "big") % METER_COUNT
            readings.append({
                "id": str(uuid.uuid4()),
                "meter_id": stable_id("meter", meter_number),
                "consumption_wh": 1,
            })

        with self.client.post(
            "/meter_readings",
            json={"readings": readings},
            name=f"/meter_readings [batch={BATCH_SIZE}]",
            catch_response=True,
        ) as response:
            if response.status_code != 201:
                response.failure(response.text)
                return
            if any(result["status"] not in ("created", "exists") for result in response.json()["results"]):
                response.failure(response.text)
