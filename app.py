from flask import Flask, request, jsonify
import os
import getpass
import logging
import re
from dotenv import load_dotenv
from ldap3 import Server, Connection, ALL, SASL, KERBEROS, ALL_ATTRIBUTES, ALL_OPERATIONAL_ATTRIBUTES, SUBTREE, ServerPool, ROUND_ROBIN
from ldap3.core.exceptions import LDAPException, LDAPBindError, LDAPSocketOpenError

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# LDAP Configuration - Fail fast if required config is missing
LDAP_SERVER = os.getenv('LDAP_SERVER')
LDAP_BASE_DN = os.getenv('LDAP_BASE_DN')
LDAP_USER_DN = os.getenv('LDAP_USER_DN')

if not LDAP_SERVER or not LDAP_BASE_DN:
    logger.error("Missing required LDAP configuration. Please set LDAP_SERVER and LDAP_BASE_DN in .env file")
    raise ValueError("Missing required LDAP configuration")

logger.info(f"LDAP Configuration loaded: Server={LDAP_SERVER}, Base DN={LDAP_BASE_DN}")

# LDAP Connection Pool Configuration
POOL_SIZE = int(os.getenv('LDAP_POOL_SIZE', '10'))
POOL_KEEPALIVE = int(os.getenv('LDAP_POOL_KEEPALIVE', '300'))  # 5 minutes

# Create LDAP server pool for high availability and load balancing
ldap_server = Server(LDAP_SERVER, get_info=ALL, connect_timeout=5)

# Note: Connection pooling in ldap3 is handled per-connection basis
# We'll implement a simple connection reuse pattern
logger.info(f"LDAP connection pool configured: size={POOL_SIZE}, keepalive={POOL_KEEPALIVE}s")

# Username validation pattern (alphanumeric, dots, hyphens, underscores only)
USERNAME_PATTERN = re.compile(r'^[a-zA-Z0-9._-]+$')

def sanitize_username(username):
    """
    Sanitize and validate username to prevent LDAP injection.
    
    Args:
        username: The username to sanitize
        
    Returns:
        Sanitized username if valid, None otherwise
    """
    if not username:
        return None
    
    # Remove whitespace
    username = username.strip()
    
    # Validate against pattern
    if not USERNAME_PATTERN.match(username):
        logger.warning(f"Invalid username format rejected: {username}")
        return None
    
    # Additional length check
    if len(username) > 64:
        logger.warning(f"Username too long rejected: {username}")
        return None
    
    # Escape special LDAP characters
    # Characters that need escaping: * ( ) \ NUL
    ldap_escape_chars = {
        '*': '\\2a',
        '(': '\\28',
        ')': '\\29',
        '\\': '\\5c',
        '\x00': '\\00'
    }
    
    for char, escape in ldap_escape_chars.items():
        username = username.replace(char, escape)
    
    return username

def get_ldap_user_info(username):
    """
    Query LDAP for user information using Windows credentials.
    Returns all user attributes from Active Directory.
    
    Args:
        username: The username to query (will be sanitized)
        
    Returns:
        dict: User attributes if found, None otherwise
        
    Raises:
        ValueError: If username is invalid
        LDAPException: If LDAP operation fails
    """
    # Sanitize username to prevent LDAP injection
    sanitized_username = sanitize_username(username)
    if not sanitized_username:
        logger.error(f"Invalid username provided: {username}")
        raise ValueError(f"Invalid username format: {username}")
    
    conn = None
    try:
        logger.info(f"Querying LDAP for user: {sanitized_username}")
        
        # Use pooled LDAP server (reuses server object)
        # This reduces connection overhead significantly
        conn = Connection(
            ldap_server,  # Use the pre-configured server pool
            authentication=SASL,
            sasl_mechanism=KERBEROS,
            auto_bind=True,
            pool_name='ldap_pool',
            pool_size=POOL_SIZE,
            pool_lifetime=POOL_KEEPALIVE
        )
        
        logger.debug(f"LDAP connection established from pool to {LDAP_SERVER}")
        
        # Search for the user by sAMAccountName
        search_filter = f'(sAMAccountName={sanitized_username})'
        
        conn.search(
            search_base=LDAP_BASE_DN,
            search_filter=search_filter,
            search_scope=SUBTREE,
            attributes=[ALL_ATTRIBUTES, ALL_OPERATIONAL_ATTRIBUTES]
        )
        
        if conn.entries:
            # Get the first entry (should be only one)
            entry = conn.entries[0]
            logger.info(f"User found: {entry.entry_dn}")
            
            # Convert LDAP entry to dictionary
            user_data = {}
            for attr in entry.entry_attributes:
                value = entry[attr].value
                # Convert lists with single items to single values
                if isinstance(value, list) and len(value) == 1:
                    value = value[0]
                # Convert bytes to string for JSON serialization
                if isinstance(value, bytes):
                    value = str(value)
                elif isinstance(value, list):
                    value = [str(v) if isinstance(v, bytes) else v for v in value]
                user_data[attr] = value
            
            return user_data
        else:
            logger.warning(f"User not found in LDAP: {sanitized_username}")
            return None
            
    except LDAPBindError as e:
        logger.error(f"LDAP bind failed: {str(e)}")
        raise
    except LDAPSocketOpenError as e:
        logger.error(f"Cannot connect to LDAP server {LDAP_SERVER}: {str(e)}")
        raise
    except LDAPException as e:
        logger.error(f"LDAP error while querying user {sanitized_username}: {str(e)}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error while querying user {sanitized_username}: {str(e)}", exc_info=True)
        raise
    finally:
        if conn:
            try:
                conn.unbind()
                logger.debug("LDAP connection closed")
            except Exception as e:
                logger.warning(f"Error closing LDAP connection: {str(e)}")

# Note: For SSPI/Windows Authentication to work, this Flask app must be deployed
# behind IIS with Windows Authentication enabled, or use winfspy/pywin32 for SSPI

@app.route('/')
def get_user():
    """
    Main route that returns the authenticated user's information.
    Similar to node-expose-sspi's sso.auth() middleware.
    """
    # When deployed behind IIS with Windows Authentication,
    # the authenticated user is available in REMOTE_USER
    remote_user = request.environ.get('REMOTE_USER') or request.environ.get('HTTP_REMOTE_USER')
    
    username = None
    domain = None
    
    if remote_user:
        # Parse domain\username format
        if '\\' in remote_user:
            domain, username = remote_user.split('\\', 1)
        elif '@' in remote_user:
            username, domain = remote_user.split('@', 1)
        else:
            username = remote_user
    
    # Return user info similar to node-expose-sspi
    return jsonify({
        'username': username,
        'domain': domain,
        'authenticated': username is not None
    })

@app.route('/api/user')
def api_user():
    """
    API endpoint that returns detailed user information from LDAP.
    
    When deployed behind IIS with Windows Authentication:
    - Gets username from REMOTE_USER environment variable
    
    When running in development mode:
    - Gets current Windows username automatically
    """
    # Try to get authenticated user from IIS
    remote_user = request.environ.get('REMOTE_USER') or request.environ.get('HTTP_REMOTE_USER')
    
    username = None
    domain = None
    auth_source = None
    
    if remote_user:
        # User authenticated via IIS Windows Authentication
        if '\\' in remote_user:
            domain, username = remote_user.split('\\', 1)
        elif '@' in remote_user:
            username, domain = remote_user.split('@', 1)
        else:
            username = remote_user
        auth_source = 'IIS Windows Authentication'
    else:
        # Development mode - get current Windows user
        username = getpass.getuser()
        domain = os.environ.get('USERDOMAIN', 'Unknown')
        auth_source = 'Current Windows User'
    
    # Query LDAP for full user details
    ldap_data = None
    ldap_error = None
    
    if username:
        try:
            ldap_data = get_ldap_user_info(username)
        except ValueError as e:
            logger.warning(f"Invalid username from auth: {username}")
            ldap_error = "Invalid username format"
        except LDAPException as e:
            logger.error(f"LDAP error for authenticated user {username}: {str(e)}")
            ldap_error = "LDAP service unavailable"
        except Exception as e:
            logger.error(f"Unexpected error for authenticated user {username}: {str(e)}", exc_info=True)
            ldap_error = "Internal error"
    
    response = {
        'user': {
            'username': username,
            'domain': domain,
            'full_name': f"{domain}\\{username}" if domain else username
        },
        'authenticated': username is not None,
        'auth_type': request.environ.get('AUTH_TYPE'),
        'auth_source': auth_source,
        'ldap_attributes': ldap_data
    }
    
    if ldap_error:
        response['ldap_error'] = ldap_error
    
    return jsonify(response)

@app.route('/api/user/<username>')
def get_user_by_username(username):
    """
    Get LDAP user information by username.
    Useful for testing without Windows Authentication.
    """
    try:
        ldap_data = get_ldap_user_info(username)
        
        if ldap_data:
            logger.info(f"Successfully retrieved data for user: {username}")
            return jsonify({
                'success': True,
                'username': username,
                'data': ldap_data
            })
        else:
            logger.warning(f"User not found: {username}")
            return jsonify({
                'success': False,
                'username': username,
                'error': 'User not found'
            }), 404
            
    except ValueError as e:
        logger.warning(f"Invalid username: {username} - {str(e)}")
        return jsonify({
            'success': False,
            'username': username,
            'error': 'Invalid username format'
        }), 400
        
    except LDAPException as e:
        logger.error(f"LDAP error for user {username}: {str(e)}")
        return jsonify({
            'success': False,
            'username': username,
            'error': 'LDAP service error'
        }), 503
        
    except Exception as e:
        logger.error(f"Unexpected error for user {username}: {str(e)}", exc_info=True)
        return jsonify({
            'success': False,
            'username': username,
            'error': 'Internal server error'
        }), 500

@app.route('/health')
def health_check():
    """
    Health check endpoint to verify LDAP connectivity.
    Returns 200 if healthy, 503 if LDAP is unavailable.
    """
    try:
        # Try to connect to LDAP server using pooled connection
        conn = Connection(
            ldap_server,  # Use pooled server
            authentication=SASL,
            sasl_mechanism=KERBEROS,
            auto_bind=True,
            pool_name='ldap_pool',
            pool_size=POOL_SIZE
        )
        conn.unbind()
        
        logger.info("Health check passed (using connection pool)")
        return jsonify({
            'status': 'healthy',
            'ldap_server': LDAP_SERVER,
            'ldap_connected': True,
            'pool_enabled': True,
            'pool_size': POOL_SIZE
        }), 200
        
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({
            'status': 'unhealthy',
            'ldap_server': LDAP_SERVER,
            'ldap_connected': False,
            'error': str(e)
        }), 503

if __name__ == '__main__':
    # Get configuration from environment
    debug_mode = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', '5000'))
    
    if debug_mode:
        logger.warning("⚠️  Running in DEBUG mode - DO NOT use in production!")
    
    logger.info(f"Starting Flask app on {host}:{port} (debug={debug_mode})")
    
    # For development - in production, deploy behind IIS with Windows Authentication
    # or use a production WSGI server like Gunicorn or uWSGI
    app.run(debug=debug_mode, host=host, port=port)
