require "benchmark"
require "prometheus_exporter"
require "prometheus_exporter/server"
require "prometheus_exporter/client"
require 'prometheus_exporter/instrumentation'

module TopologicalInventory
  module Persister
    class Metrics
      def initialize(port = 9394)
        return if port == 0

        configure_server(port)
        configure_metrics
      end

      # @param status [Symbol] - :success, :error, :skipped, :requeued
      # @param labels [Hash] - keys == :error_class,
      def record_process(status = :success, labels = {})
        @process_counter&.observe(1, labels.merge(:result => status.to_s))
      end

      def record_process_timing
        time = Benchmark.realtime { yield }
        @process_timer&.observe(time)
      end

      def stop_server
        @server&.stop
      end

      private

      def configure_server(port)
        @server = PrometheusExporter::Server::WebServer.new(:port => port)
        @server.start

        PrometheusExporter::Client.default = PrometheusExporter::LocalClient.new(:collector => @server.collector)
      end

      def configure_metrics
        PrometheusExporter::Instrumentation::Process.start

        PrometheusExporter::Metric::Base.default_prefix = "topological_inventory_persister_"

        @process_counter = PrometheusExporter::Metric::Counter.new("messages_total", "total number of messages processed")
        @process_timer = PrometheusExporter::Metric::Histogram.new("message_process_seconds", "time it took to process messages")
        @server.collector.register_metric(@process_counter)
        @server.collector.register_metric(@process_timer)
      end
    end
  end
end
