from flask import Flask, Response
import os
import requests
import threading
import time
from datetime import datetime

app = Flask(__name__)

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
GITHUB_REPO = os.environ.get("GITHUB_REPO", "aridamansohal/devboard")
REFRESH_INTERVAL = int(os.environ.get("REFRESH_INTERVAL", "300"))

HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}

metrics_data = {
    "deployments": 0,
    "failed_deployments": 0,
    "change_failure_rate": 0,
    "average_lead_time": 0,
}

metrics_lock = threading.Lock()


def github_api(path, params=None):
    url = f"https://api.github.com{path}"

    response = requests.get(
        url,
        headers=HEADERS,
        params=params,
        timeout=20,
    )

    response.raise_for_status()
    return response.json()


def parse_time(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def calculate_metrics():
    runs = github_api(
        f"/repos/{GITHUB_REPO}/actions/runs",
        {
            "per_page": 100,
            "branch": "master",
        },
    )["workflow_runs"]

    deployments = 0
    failed_deployments = 0
    deployment_times = []

    for run in runs:

        if run.get("name") != "DevSecOps":
            continue

        jobs = github_api(
            f"/repos/{GITHUB_REPO}/actions/runs/{run['id']}/jobs"
        )["jobs"]

        deploy_job = next(
            (
                job
                for job in jobs
                if job["name"] == "deploy / deploy"
            ),
            None,
        )

        if not deploy_job:
            continue

        conclusion = deploy_job.get("conclusion")

        if conclusion == "success":
            deployments += 1

            if deploy_job.get("completed_at"):
                start = parse_time(run["created_at"])
                end = parse_time(deploy_job["completed_at"])

                deployment_times.append(
                    (end - start).total_seconds()
                )

        elif conclusion == "failure":
            failed_deployments += 1

    total_deployments = deployments + failed_deployments

    if total_deployments:
        change_failure_rate = (
            failed_deployments / total_deployments
        ) * 100
    else:
        change_failure_rate = 0

    if deployment_times:
        average_lead_time = (
            sum(deployment_times)
            / len(deployment_times)
        )
    else:
        average_lead_time = 0

    with metrics_lock:
        metrics_data["deployments"] = deployments
        metrics_data["failed_deployments"] = failed_deployments
        metrics_data["change_failure_rate"] = change_failure_rate
        metrics_data["average_lead_time"] = average_lead_time


def refresh_loop():
    while True:
        try:
            calculate_metrics()
            print("DORA metrics refreshed", flush=True)
        except Exception as error:
            print(
                f"DORA refresh failed: {error}",
                flush=True,
            )

        time.sleep(REFRESH_INTERVAL)


@app.route("/metrics")
def metrics():

    with metrics_lock:
        deployments = metrics_data["deployments"]
        failed_deployments = metrics_data["failed_deployments"]
        change_failure_rate = metrics_data["change_failure_rate"]
        average_lead_time = metrics_data["average_lead_time"]

    output = f"""
# HELP dora_deployments_total Total successful deployments
# TYPE dora_deployments_total counter
dora_deployments_total {deployments}

# HELP dora_failed_deployments_total Total failed deployments
# TYPE dora_failed_deployments_total counter
dora_failed_deployments_total {failed_deployments}

# HELP dora_change_failure_rate_percent Change failure rate percentage
# TYPE dora_change_failure_rate_percent gauge
dora_change_failure_rate_percent {change_failure_rate}

# HELP dora_average_lead_time_seconds Average time from workflow creation to successful deployment
# TYPE dora_average_lead_time_seconds gauge
dora_average_lead_time_seconds {average_lead_time}

# HELP dora_deployment_frequency_total Successful deployments observed
# TYPE dora_deployment_frequency_total gauge
dora_deployment_frequency_total {deployments}
"""

    return Response(
        output,
        mimetype="text/plain",
    )


@app.route("/")
def health():
    return "DevBoard DORA exporter OK\n"


if __name__ == "__main__":

    refresh_thread = threading.Thread(
        target=refresh_loop,
        daemon=True,
    )

    refresh_thread.start()

    app.run(
        host="0.0.0.0",
        port=8000,
    )
