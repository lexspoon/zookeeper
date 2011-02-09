# The low-level wrapper-specific methods for the C lib
# subclassed by the top-level Zookeeper class
class ZookeeperBase < CZookeeper
  include ZookeeperCommon
  include ZookeeperCallbacks
  include ZookeeperConstants
  include ZookeeperExceptions
  include ZookeeperACLs
  include ZookeeperStat


  ZKRB_GLOBAL_CB_REQ   = -1

  # debug levels
  ZOO_LOG_LEVEL_ERROR  = 1
  ZOO_LOG_LEVEL_WARN   = 2
  ZOO_LOG_LEVEL_INFO   = 3
  ZOO_LOG_LEVEL_DEBUG  = 4
  
  def reopen(timeout = 10)
    init(@host)
    if timeout > 0
      time_to_stop = Time.now + timeout
      until state == Zookeeper::ZOO_CONNECTED_STATE
        break if Time.now > time_to_stop
        sleep 0.1
      end
    end
    # flushes all outstanding watcher reqs.
    @watcher_reqs = { ZKRB_GLOBAL_CB_REQ => { :watcher => get_default_global_watcher } }
    state
  end

  def initialize(host, timeout = 10)
    @watcher_reqs = {}
    @completion_reqs = {}
    @req_mutex = Mutex.new
    @current_req_id = 1
    @host = host
    reopen(timeout)
    return nil unless connected?
    setup_dispatch_thread!
  end
  
  # if either of these happen, the user will need to renegotiate a connection via reopen
  def assert_open
    raise ZookeeperException::SessionExpired if state == ZOO_EXPIRED_SESSION_STATE
    raise ZookeeperException::ConnectionClosed unless connected?
  end

  def connected?
    state == ZOO_CONNECTED_STATE
  end

  def connecting?
    state == ZOO_CONNECTING_STATE
  end

  def associating?
    state == ZOO_ASSOCIATING_STATE
  end

protected
  # XXX: for some reason this doesn't work from ZookeeperCommon
  def setup_dispatch_thread!
    @dispatcher = Thread.new {
      while true do
        dispatch_next_callback
      end
    }
  end

  # TODO: Make all global puts configurable
  def get_default_global_watcher
    Proc.new { |args|
#       $stderr.puts "Ruby ZK Global CB called type=#{event_by_value(args[:type])} state=#{state_by_value(args[:state])}"
      true
    }
  end
end

