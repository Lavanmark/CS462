import requests
import datetime
import time
import json


class test_sensors():
    bURL = "http://localhost:8080/"
    manager_eci = "Cg5Wisb2AXSDMR42c1CJB7"

    sensor_map = {}

    def __init__(self):
        super().__init__()
        self.sensor_map = {
            "Test 1": "",
            "Test 2": "",
            "Test 3": "",
            "Test 4": "",
            "Test 5": "",
            "Test 6": "",
            "Test 7": "",
            "Test 8": "",
            "Test 9": "",
            "Test 0": ""
        }

    def create_sensor(self, sensor_name):
        csURL = "{}sky/event/{}/eid/sensor/new_sensor".format(
            self.bURL, self.manager_eci)
        body = {
            "sensor_name": sensor_name
        }
        r = requests.post(url=csURL, json=body)
        if "directives" in r.json():
            if "options" in r.json()["directives"][0]:
                if "pico" in r.json()["directives"][0]["options"]:
                    if "eci" in r.json()["directives"][0]["options"]["pico"]:
                        self.sensor_map[sensor_name] = r.json(
                        )["directives"][0]["options"]["pico"]["eci"]
        return r.json()  # self.sensor_map[sensor_name]

    def remove_sensor(self, sensor_name):
        rsURL = "{}sky/event/{}/eid/sensor/unneeded_sensor".format(
            self.bURL, self.manager_eci)
        body = {
            "sensor_name": sensor_name
        }
        r = requests.post(url=rsURL, json=body)
        if r.status_code == 200:
            self.sensor_map[sensor_name] = ""
        return r.json()

    def get_sensors(self):
        gsURL = "{}sky/cloud/{}/manage_sensors/sensors".format(
            self.bURL, self.manager_eci)
        r = requests.get(url=gsURL)
        return r.json()

    def get_all_data(self):
        dURL = "{}sky/cloud/{}/manage_sensors/get_all_temps".format(
            self.bURL, self.manager_eci)
        r = requests.get(url=dURL)
        return r.json()

    def get_violations(self, sensor_name):
        vURL = "{}sky/cloud/{}/temperature_store/threshold_violations".format(
            self.bURL, self.sensor_map[sensor_name])
        r = requests.get(url=vURL)
        return r.json()

    def get_profile(self, sensor_name):
        pURL = "{}sky/cloud/{}/sensor_profile/get_profile".format(
            self.bURL, self.sensor_map[sensor_name])
        r = requests.get(url=pURL)
        return r.json()

    def update_profile(self, profile, sensor_name):
        upURL = "{}sky/event/{}/eid/sensor/profile_updated".format(
            self.bURL, self.sensor_map[sensor_name])
        r = requests.post(url=upURL, json=profile)
        return r.json()

    def fake_data(self, num_to_fake, sensor_name):
        tfURL = "{}sky/event/{}/eid/testing/fake_temps".format(
            self.bURL, self.sensor_map[sensor_name])
        body = {
            "number": num_to_fake
        }
        r = requests.post(url=tfURL, json=body)
        return r.json()

    def fake_one_data(self, data_to_fake, sensor_name):
        tfURL = "{}sky/event/{}/eid/testing/fake_temp".format(
            self.bURL, self.sensor_map[sensor_name])
        body = {
            "temperature": data_to_fake
        }
        r = requests.post(url=tfURL, json=body)
        return r.json()


def create_sensors(test_harness):
    for sensor in test_harness.sensor_map:
        data = test_harness.create_sensor(sensor)
        # print(data)


def delete_sensors(test_harness):
    for sensor in test_harness.sensor_map:
        data = test_harness.remove_sensor(sensor)


def fake_all_data(test_harness, num_to_fake):
    for sensor in test_harness.sensor_map:
        data = test_harness.fake_data(num_to_fake, sensor)


def print_picos(test_harness):
    print(json.dumps(test_harness.get_sensors(), indent=2))


def print_temp_data(test_harness):
    print(json.dumps(test_harness.get_all_data(), indent=2))


test_harness = test_sensors()

print("Existing Picos:")
print_picos(test_harness)
print("Deleting Potential Old 'Test X' Picos")
delete_sensors(test_harness)

print("waiting for delete events...")
time.sleep(2)
print_picos(test_harness)


print("\n\n\nCreating Picos")
create_sensors(test_harness)
print_picos(test_harness)

print("waiting for create events...")
time.sleep(2)

print("\n\n\nTesting Duplicate Pico")
duplicate = test_harness.create_sensor("Test 0")
print(json.dumps(duplicate, indent=2))

print("\n\n\nTesting deleting single pico")
del_res = test_harness.remove_sensor("Test 0")
test_harness.sensor_map.pop("Test 0")
print("- response -")
print(json.dumps(del_res, indent=2))

print("waiting for delete event...")
time.sleep(2)

print("- all remaining picos -")
print_picos(test_harness)


print("\n\n\nTesting temperature data")
print("- baseline (all empty) -")
print_temp_data(test_harness)
print("\nadding 2 items of fake data to 'Test 1'")
test_harness.fake_data(2, "Test 1")
print("waiting for data creation...")
time.sleep(2)
print("\n- results -")
print_temp_data(test_harness)

print("pausing for user to review...")
time.sleep(3)

print("\n\nadding a few items of fake data to all picos")
fake_all_data(test_harness, 3)
print("waiting for data creation...")
time.sleep(5)
print("- results -")
print_temp_data(test_harness)

print("pausing for user to review...")
time.sleep(5)

print("\n\n\nTesting Profiles")
print("Getting profile information for 'Test 1'")
prof_info = test_harness.get_profile("Test 1")
print(json.dumps(prof_info, indent=2))
print("\n\nUpdating profile...")
prof_info["name"] = "Old Man"
prof_info["location"] = "Outer Space"
prof_info["threshold"] = 70
print("updating info to:")
print(json.dumps(prof_info, indent=2))
test_harness.update_profile(prof_info, "Test 1")
print("waiting for update...")
time.sleep(2)
print("getting updated profile:")
prof_info = test_harness.get_profile("Test 1")
print(json.dumps(prof_info, indent=2))

print("\n\n\nTesting Threshold Violation")
test_harness.fake_one_data(90, "Test 1")
print("waiting for violation to register...")
time.sleep(2)
print("getting violations")
violations = test_harness.get_violations("Test 1")
print(json.dumps(violations, indent=2))

print("\n\n\nPrinting all temperature data one more time")
print_temp_data(test_harness)

print("\n\n\nTesting Complete: Deleting Picos")
delete_sensors(test_harness)
