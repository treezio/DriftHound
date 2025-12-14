import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static targets = ["modal", "title", "body", "canvas"]

  connect() {
    this.modalChart = null;
    this.boundKeyHandler = this.handleKeydown.bind(this);
  }

  open(event) {
    // Prevent modal from opening when clicking on info icon
    if (event.target.closest('.chart-info')) {
      event.stopPropagation();
      return;
    }

    const chartCard = event.currentTarget;
    const chartId = chartCard.dataset.chartId;
    const title = chartCard.querySelector('h3').textContent.trim();

    // Get the chart instance from the card
    const chartContainer = chartCard.querySelector('.chart-container');
    const canvas = chartContainer.querySelector('canvas');

    // Find the Chart.js instance
    const originalChart = Chart.getChart(canvas);
    if (!originalChart) return;

    // Set title
    this.titleTarget.textContent = title;

    // Clone chart configuration for modal
    const config = this.cloneChartConfig(originalChart);

    // Destroy previous modal chart if exists
    if (this.modalChart) {
      this.modalChart.destroy();
    }

    // Create new chart in modal
    this.modalChart = new Chart(this.canvasTarget, config);

    // Show modal
    this.modalTarget.classList.add('active');
    document.body.style.overflow = 'hidden';

    // Add keyboard listener
    document.addEventListener('keydown', this.boundKeyHandler);
  }

  close() {
    this.modalTarget.classList.remove('active');
    document.body.style.overflow = '';

    // Remove keyboard listener
    document.removeEventListener('keydown', this.boundKeyHandler);

    // Destroy modal chart
    if (this.modalChart) {
      this.modalChart.destroy();
      this.modalChart = null;
    }
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.close();
    }
  }

  cloneChartConfig(chart) {
    const type = chart.config.type;
    const data = JSON.parse(JSON.stringify(chart.config.data));
    const options = JSON.parse(JSON.stringify(chart.config.options));

    // Enhance options for modal view
    options.maintainAspectRatio = false;

    // Increase font sizes for modal
    if (options.plugins && options.plugins.legend && options.plugins.legend.labels) {
      options.plugins.legend.labels.font = { size: 14 };
      options.plugins.legend.labels.padding = 20;
    }

    if (options.plugins && options.plugins.tooltip) {
      options.plugins.tooltip.titleFont = { size: 16 };
      options.plugins.tooltip.bodyFont = { size: 14 };
    }

    return { type, data, options };
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundKeyHandler);
    if (this.modalChart) {
      this.modalChart.destroy();
    }
  }
}
