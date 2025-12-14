import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    this.createChart(this.dataValue);

    this.boundHandleStatusFilter = this.handleStatusFilter.bind(this);
    document.addEventListener('dashboard-filter:filterStatus', this.boundHandleStatusFilter);
  }

  handleStatusFilter(event) {
    const status = event.detail.status || '';
    this.applyStatusFilter(status);
  }

  applyStatusFilter(status) {
    // Show/hide datasets based on status filter
    // Index: 0=ok, 1=drift, 2=error
    const statusMap = { 'ok': 0, 'drift': 1, 'error': 2 };

    this.chart.data.datasets.forEach((dataset, index) => {
      if (!status) {
        dataset.hidden = false;
      } else {
        dataset.hidden = (statusMap[status] !== index);
      }
    });
    this.chart.update();
  }

  createChart(data) {
    this.chart = new Chart(this.canvasTarget, {
      type: "bar",
      data: {
        labels: data.labels,
        datasets: [
          {
            label: "OK",
            data: data.ok,
            backgroundColor: "rgba(34, 197, 94, 0.8)",
            borderColor: "#22c55e",
            borderWidth: 1
          },
          {
            label: "Drift",
            data: data.drift,
            backgroundColor: "rgba(245, 158, 11, 0.8)",
            borderColor: "#f59e0b",
            borderWidth: 1
          },
          {
            label: "Error",
            data: data.error,
            backgroundColor: "rgba(239, 68, 68, 0.8)",
            borderColor: "#ef4444",
            borderWidth: 1
          }
        ]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              usePointStyle: true,
              padding: 15
            }
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            callbacks: {
              title: function(tooltipItems) {
                // Show full label in tooltip title
                return tooltipItems[0].label;
              }
            }
          }
        },
        scales: {
          x: {
            stacked: true,
            beginAtZero: true,
            ticks: {
              stepSize: 1,
              precision: 0
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)"
            }
          },
          y: {
            stacked: true,
            grid: {
              display: false
            },
            ticks: {
              callback: function(value, index) {
                const label = this.getLabelForValue(value);
                return label.length > 15 ? label.substring(0, 15) + '…' : label;
              }
            }
          }
        }
      }
    });
  }

  disconnect() {
    document.removeEventListener('dashboard-filter:filterStatus', this.boundHandleStatusFilter);
    if (this.chart) {
      this.chart.destroy();
    }
  }
}
