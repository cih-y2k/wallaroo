/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "collections"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/partitioning"
use "wallaroo/ent/recovery"
use "wallaroo/ent/router_registry"
use "wallaroo/core/initialization"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"

class val ConnectorSourceListenerBuilder[In: Any val]
  let _worker_name: WorkerName
  let _pipeline_name: String
  let _runner_builder: RunnerBuilder
  let _partitioner_builder: PartitionerBuilder
  let _router: Router
  let _metrics_conn: MetricsSink
  let _metrics_reporter: MetricsReporter
  let _router_registry: RouterRegistry
  let _outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val
  let _event_log: EventLog
  let _auth: AmbientAuth
  let _layout_initializer: LayoutInitializer
  let _recovering: Bool
  let _target_router: Router
  let _parallelism: USize
  let _handler: FramedSourceHandler[In] val
  let _host: String
  let _service: String

  new val create(worker_name: WorkerName, pipeline_name: String,
    runner_builder: RunnerBuilder, partitioner_builder: PartitionerBuilder,
    router: Router, metrics_conn: MetricsSink,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    recovering: Bool, target_router: Router = EmptyRouter, parallelism: USize,
    handler: FramedSourceHandler[In] val,
    host: String = "", service: String = "0")
  =>
    _worker_name = worker_name
    _pipeline_name = pipeline_name
    _runner_builder = runner_builder
    _partitioner_builder = partitioner_builder
    _router = router
    _metrics_conn = metrics_conn
    _metrics_reporter = consume metrics_reporter
    _router_registry = router_registry
    _outgoing_boundary_builders = outgoing_boundary_builders
    _event_log = event_log
    _auth = auth
    _layout_initializer = layout_initializer
    _recovering = recovering
    _target_router = target_router
    _parallelism = parallelism
    _handler = handler
    _host = host
    _service = service

  fun apply(env: Env): SourceListener =>
    ConnectorSourceListener[In](env, _worker_name, _pipeline_name,
      _runner_builder, _partitioner_builder,
      _router, _metrics_conn, _metrics_reporter.clone(), _router_registry,
      _outgoing_boundary_builders, _event_log, _auth, _layout_initializer,
      _recovering, _target_router, _parallelism, _handler, _host, _service)

class val ConnectorSourceListenerBuilderBuilder[In: Any val]
  let _host: String
  let _service: String
  let _parallelism: USize
  let _handler: FramedSourceHandler[In] val

  new val create(host: String, service: String, parallelism: USize,
    handler: FramedSourceHandler[In] val)
  =>
    _host = host
    _service = service
    _parallelism = parallelism
    _handler = handler

  fun apply(worker_name: String, pipeline_name: String,
    runner_builder: RunnerBuilder, partitioner_builder: PartitionerBuilder,
    router: Router, metrics_conn: MetricsSink,
    metrics_reporter: MetricsReporter iso, router_registry: RouterRegistry,
    outgoing_boundary_builders: Map[String, OutgoingBoundaryBuilder] val,
    event_log: EventLog, auth: AmbientAuth,
    layout_initializer: LayoutInitializer,
    recovering: Bool, target_router: Router = EmptyRouter):
    ConnectorSourceListenerBuilder[In]
  =>
    ConnectorSourceListenerBuilder[In](worker_name, pipeline_name,
      runner_builder, partitioner_builder, router, metrics_conn,
      consume metrics_reporter, router_registry, outgoing_boundary_builders,
      event_log, auth, layout_initializer, recovering, target_router,
      _parallelism, _handler, _host, _service)
