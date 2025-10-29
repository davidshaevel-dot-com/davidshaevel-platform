#!/bin/bash
#
# Backend API Integration Tests
# 
# This script performs automated integration testing of the backend API
# by starting PostgreSQL and backend containers, running comprehensive
# tests, and cleaning up afterward.
#
# Usage:
#   ./backend/scripts/test-local.sh              # Run all tests
#   ./backend/scripts/test-local.sh -v           # Verbose mode
#   ./backend/scripts/test-local.sh --no-cleanup # Skip cleanup for debugging
#   ./backend/scripts/test-local.sh -q           # Quiet mode (for CI/CD)
#

set -e  # Exit on error (but we'll handle errors ourselves)

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$BACKEND_DIR")"

POSTGRES_CONTAINER="postgres-test"
BACKEND_CONTAINER="backend-test"
BACKEND_IMAGE="davidshaevel-backend-test"

POSTGRES_PORT=5433  # Use different port to avoid conflicts
BACKEND_PORT=3001

DB_PASSWORD="test_password_123"
DB_NAME="davidshaevel_test"
DB_USER="dbadmin"

BACKEND_URL="http://localhost:${BACKEND_PORT}"
API_URL="${BACKEND_URL}/api"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Flags
VERBOSE=false
NO_CLEANUP=false
QUIET=false

# Colors (disabled in quiet mode)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    if [[ "$QUIET" == false ]]; then
        echo -e "$1"
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

log_success() {
    log "${GREEN}✓${NC} $1"
}

log_error() {
    log "${RED}✗${NC} $1"
}

log_section() {
    if [[ "$QUIET" == false ]]; then
        echo ""
        echo -e "${BLUE}=== $1 ===${NC}"
        echo ""
    fi
}

# Cleanup function (always runs on exit)
cleanup() {
    if [[ "$NO_CLEANUP" == true ]]; then
        log_verbose "Skipping cleanup (--no-cleanup flag)"
        return
    fi

    log_section "Cleanup"
    
    log "Stopping containers..."
    docker stop "$BACKEND_CONTAINER" "$POSTGRES_CONTAINER" 2>/dev/null || true
    log_success "Containers stopped"
    
    log "Removing containers..."
    docker rm "$BACKEND_CONTAINER" "$POSTGRES_CONTAINER" 2>/dev/null || true
    log_success "Containers removed"
}

# Register cleanup to run on exit
trap cleanup EXIT

# Run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$QUIET" == false ]]; then
        echo -n "[${TESTS_TOTAL}] ${test_name}... "
    fi
    
    if eval "$test_command" > /dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success ""
        log_verbose "Test passed: $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "FAILED"
        if [[ "$VERBOSE" == true ]]; then
            log_error "Test failed: $test_name"
            log_error "Command: $test_command"
        fi
        return 1
    fi
}

# Wait for service to be ready
wait_for_service() {
    local url="$1"
    local max_attempts=30
    local attempt=1
    
    log_verbose "Waiting for service at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            log_verbose "Service ready after $attempt attempts"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    log_error "Service not ready after $max_attempts attempts"
    return 1
}

# =============================================================================
# Parse Arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-cleanup)
            NO_CLEANUP=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose      Enable verbose output"
            echo "  --no-cleanup       Skip container cleanup (for debugging)"
            echo "  -q, --quiet        Quiet mode (minimal output, for CI/CD)"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with -h for help"
            exit 1
            ;;
    esac
done

# Disable colors in quiet mode
if [[ "$QUIET" == true ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# =============================================================================
# Main Script
# =============================================================================

log_section "Backend API Integration Tests"

# -----------------------------------------------------------------------------
# 1. Check Dependencies
# -----------------------------------------------------------------------------

log "Checking dependencies..."

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    log_error "curl is not installed or not in PATH"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_error "jq is not installed or not in PATH"
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    exit 1
fi

log_success "All dependencies available"

# -----------------------------------------------------------------------------
# 2. Cleanup any existing containers
# -----------------------------------------------------------------------------

log "Cleaning up any existing test containers..."
docker stop "$BACKEND_CONTAINER" "$POSTGRES_CONTAINER" 2>/dev/null || true
docker rm "$BACKEND_CONTAINER" "$POSTGRES_CONTAINER" 2>/dev/null || true
log_success "Cleanup complete"

# -----------------------------------------------------------------------------
# 3. Build Backend Docker Image
# -----------------------------------------------------------------------------

log "Building backend Docker image..."
log_verbose "Building from: $BACKEND_DIR"
log_verbose "Image name: $BACKEND_IMAGE"

cd "$BACKEND_DIR"
if docker build -t "$BACKEND_IMAGE" . > /dev/null 2>&1; then
    log_success "Backend image built"
else
    log_error "Failed to build backend image"
    exit 1
fi

# -----------------------------------------------------------------------------
# 4. Start PostgreSQL Container
# -----------------------------------------------------------------------------

log "Starting PostgreSQL container..."

docker run -d \
    --name "$POSTGRES_CONTAINER" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -e POSTGRES_DB="$DB_NAME" \
    -p "${POSTGRES_PORT}:5432" \
    postgres:15 > /dev/null

log_success "PostgreSQL container started"

# Wait for PostgreSQL to be ready
log "Waiting for PostgreSQL to be ready..."
sleep 5

# Verify PostgreSQL is responding
if docker exec "$POSTGRES_CONTAINER" pg_isready -U "$DB_USER" > /dev/null 2>&1; then
    log_success "PostgreSQL is ready"
else
    log_error "PostgreSQL did not start correctly"
    docker logs "$POSTGRES_CONTAINER"
    exit 1
fi

# -----------------------------------------------------------------------------
# 5. Start Backend Container (Development Mode)
# -----------------------------------------------------------------------------

log "Starting backend container (development mode)..."

docker run -d \
    --name "$BACKEND_CONTAINER" \
    -e NODE_ENV=development \
    -e DB_HOST=host.docker.internal \
    -e DB_PORT=5433 \
    -e DB_USERNAME="$DB_USER" \
    -e DB_PASSWORD="$DB_PASSWORD" \
    -e DB_NAME="$DB_NAME" \
    -e PORT="$BACKEND_PORT" \
    -p "${BACKEND_PORT}:${BACKEND_PORT}" \
    "$BACKEND_IMAGE" > /dev/null

log_success "Backend container started"

# Wait for backend to be ready
log "Waiting for backend to be ready..."
if wait_for_service "${API_URL}/health"; then
    log_success "Backend is ready"
else
    log_error "Backend did not start correctly"
    log_error "Container logs:"
    docker logs "$BACKEND_CONTAINER"
    exit 1
fi

# -----------------------------------------------------------------------------
# 6. Run Development Mode Tests
# -----------------------------------------------------------------------------

log_section "Development Mode Tests"

# Test 1: Health check (DB connected)
run_test "Health check (DB connected)" \
    "curl -f -s '${API_URL}/health' | jq -e '.status == \"healthy\" and .database.status == \"connected\"'"

# Test 2: Health check returns development error details
run_test "Health check shows error details in dev mode" \
    "curl -f -s '${API_URL}/health' | jq -e '.environment == \"development\"'"

# Test 3: Metrics endpoint
run_test "Metrics endpoint returns Prometheus format" \
    "curl -f -s '${API_URL}/metrics' | grep -q 'backend_uptime_seconds'"

# Test 4: Create project with native array
PROJECT_ID=""
run_test "Create project (native array type)" \
    "PROJECT_ID=\$(curl -f -s -X POST '${API_URL}/projects' \
        -H 'Content-Type: application/json' \
        -d '{
            \"title\": \"Test Project\",
            \"description\": \"Testing native PostgreSQL arrays\",
            \"technologies\": [\"AWS\", \"TypeScript\", \"PostgreSQL\"]
        }' | jq -r '.id') && [ -n \"\$PROJECT_ID\" ]"

# Capture project ID for subsequent tests
PROJECT_ID=$(curl -f -s -X POST "${API_URL}/projects" \
    -H 'Content-Type: application/json' \
    -d '{
        "title": "Test Project 2",
        "description": "For update and delete tests",
        "technologies": ["Docker", "Nest.js"]
    }' | jq -r '.id')

log_verbose "Created project with ID: $PROJECT_ID"

# Test 5: Get project
run_test "Get project by ID" \
    "curl -f -s '${API_URL}/projects/${PROJECT_ID}' | jq -e '.id == \"${PROJECT_ID}\"'"

# Test 6: Update project (tests preload optimization)
run_test "Update project (optimized query)" \
    "curl -f -s -X PUT '${API_URL}/projects/${PROJECT_ID}' \
        -H 'Content-Type: application/json' \
        -d '{
            \"title\": \"Updated Test Project\",
            \"description\": \"Testing update optimization\"
        }' | jq -e '.title == \"Updated Test Project\"'"

# Test 7: Get all projects
run_test "Get all projects" \
    "curl -f -s '${API_URL}/projects' | jq -e 'length >= 2'"

# Test 8: Invalid UUID validation
run_test "Invalid UUID returns 400" \
    "! curl -f -s '${API_URL}/projects/not-a-uuid' 2>/dev/null"

# Test 9: Missing required fields
run_test "Missing required fields returns 400" \
    "! curl -f -s -X POST '${API_URL}/projects' \
        -H 'Content-Type: application/json' \
        -d '{}' 2>/dev/null"

# Test 10: Delete project
run_test "Delete project returns 204" \
    "curl -f -s -w '%{http_code}' -X DELETE '${API_URL}/projects/${PROJECT_ID}' -o /dev/null | grep -q '204'"

# -----------------------------------------------------------------------------
# 7. Verify Database Integration
# -----------------------------------------------------------------------------

log_section "Database Verification"

# Test 11: Verify native PostgreSQL array type
run_test "Native text[] array type in database" \
    "docker exec '$POSTGRES_CONTAINER' psql -U '$DB_USER' -d '$DB_NAME' \
        -c \"SELECT column_name, data_type FROM information_schema.columns \
            WHERE table_name = 'projects' AND column_name = 'technologies';\" \
        | grep -q 'ARRAY'"

# Test 12: Verify data persistence
run_test "Data persists in database" \
    "docker exec '$POSTGRES_CONTAINER' psql -U '$DB_USER' -d '$DB_NAME' \
        -t -c 'SELECT COUNT(*) FROM projects;' | grep -q '[0-9]'"

# -----------------------------------------------------------------------------
# 8. Test Health Check with DB Down
# -----------------------------------------------------------------------------

log_section "Error Handling Tests"

# Stop PostgreSQL temporarily
log "Stopping PostgreSQL temporarily..."
docker stop "$POSTGRES_CONTAINER" > /dev/null
log_success "PostgreSQL stopped"

# Wait for backend to detect disconnection
sleep 2

# Test 13: Health check returns 503 when DB is down
run_test "Health check returns 503 when DB down" \
    "HTTP_CODE=\$(curl -s -w '%{http_code}' '${API_URL}/health' -o /dev/null); [ \"\$HTTP_CODE\" = \"503\" ]"

# Restart PostgreSQL
log "Restarting PostgreSQL..."
docker start "$POSTGRES_CONTAINER" > /dev/null
sleep 3
log_success "PostgreSQL restarted"

# Wait for backend to reconnect
log "Waiting for backend to reconnect..."
sleep 3

# Verify backend reconnected
if wait_for_service "${API_URL}/health"; then
    log_success "Backend reconnected to database"
else
    log_error "Backend did not reconnect"
fi

# -----------------------------------------------------------------------------
# 9. Test Production Mode
# -----------------------------------------------------------------------------

log_section "Production Mode Tests"

log "Stopping development backend..."
docker stop "$BACKEND_CONTAINER" > /dev/null
docker rm "$BACKEND_CONTAINER" > /dev/null

log "Starting backend in production mode..."
docker run -d \
    --name "$BACKEND_CONTAINER" \
    -e NODE_ENV=production \
    -e DB_HOST=host.docker.internal \
    -e DB_PORT=5433 \
    -e DB_USERNAME="$DB_USER" \
    -e DB_PASSWORD="$DB_PASSWORD" \
    -e DB_NAME="$DB_NAME" \
    -e PORT="$BACKEND_PORT" \
    -e FRONTEND_URL="https://davidshaevel.com" \
    -p "${BACKEND_PORT}:${BACKEND_PORT}" \
    "$BACKEND_IMAGE" > /dev/null

log_success "Production backend started"

# Wait for backend to be ready
if wait_for_service "${API_URL}/health"; then
    log_success "Production backend is ready"
else
    log_error "Production backend did not start"
    exit 1
fi

# Test 14: Error details hidden in production
# Stop DB again to trigger error
docker stop "$POSTGRES_CONTAINER" > /dev/null
sleep 2

run_test "Error details hidden in production" \
    "curl -s '${API_URL}/health' | jq -e '.database.error == null'"

# Restart for cleanup
docker start "$POSTGRES_CONTAINER" > /dev/null
sleep 2

# -----------------------------------------------------------------------------
# 10. Results Summary
# -----------------------------------------------------------------------------

log_section "Results"

log "Total Tests: ${TESTS_TOTAL}"
log "Passed: ${GREEN}${TESTS_PASSED}${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    log "Failed: ${RED}${TESTS_FAILED}${NC}"
else
    log "Failed: ${TESTS_FAILED}"
fi

if [ $TESTS_TOTAL -gt 0 ]; then
    SUCCESS_RATE=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
    log "Success Rate: ${SUCCESS_RATE}%"
fi

echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    log "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    log "${RED}Some tests failed ✗${NC}"
    exit 1
fi

