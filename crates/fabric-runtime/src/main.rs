//! Fabric Runtime v0.1
//! Axum API layer wiring Control Plane + Core execution loop

use axum::{routing::{get, post}, Json, Router};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};

use fabric_control_plane::ControlPlane;
use fabric_core::{FabricCore, Identity};
use serde_json::json;
use chrono;

#[derive(Debug, Deserialize)]
pub struct ExecuteRequest {
    pub org: String,
    pub action: String,
    pub source: String,
    pub target: String,
    pub payload: serde_json::Value,
}

#[derive(Debug, Serialize)]
pub struct ExecuteResponse {
    pub allowed: bool,
    pub reason: String,
    pub event_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct Health {
    pub status: String,
    pub system: String,
}

// -----------------------------
// Runtime State (FULL PIPELINE)
// -----------------------------

#[derive(Clone)]
pub struct RuntimeState {
    pub control_plane: ControlPlane,
    pub core: Arc<Mutex<FabricCore>>,
}

impl RuntimeState {
    pub fn new() -> Self {
        Self {
            control_plane: ControlPlane::new(),
            core: Arc::new(Mutex::new(FabricCore::new())),
        }
    }

    pub fn execute(&self, req: ExecuteRequest) -> ExecuteResponse {
        // 1. Control Plane evaluation
        let eval = self
            .control_plane
            .evaluate(&req.org, &req.action, &req.source, &req.target);

        if !eval.allowed {
            return ExecuteResponse {
                allowed: false,
                reason: eval.reason,
                event_id: None,
            };
        }

        // 2. Core event execution
        let identity = Identity {
            id: req.source.clone(),
            org: req.org.clone(),
            role: "runtime-agent".to_string(),
        };

        let mut core = self.core.lock().unwrap();

        let event = core.execute(
            identity,
            &req.action,
            json!(req.payload),
            chrono::Utc::now().timestamp(),
        );

        ExecuteResponse {
            allowed: true,
            reason: "EXECUTED".to_string(),
            event_id: Some(event.event_id),
        }
    }
}

async fn execute_handler(
    axum::extract::State(state): axum::extract::State<RuntimeState>,
    Json(req): Json<ExecuteRequest>,
) -> Json<ExecuteResponse> {
    Json(state.execute(req))
}

async fn health() -> Json<Health> {
    Json(Health {
        status: "ok".into(),
        system: "fabric-runtime-v0.1-full-wired".into(),
    })
}

#[tokio::main]
async fn main() {
    let state = RuntimeState::new();

    let app = Router::new()
        .route("/health", get(health))
        .route("/fabric/execute", post(execute_handler))
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));

    println!("🚀 Fabric FULL Runtime (Control Plane + Core Wired) on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}