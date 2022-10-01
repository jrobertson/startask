!#/usr/bin/env ruby

# file: startask.rb
# description: An experimental gem representing the STAR technique.

require 'kvx'
require 'rxfhelper'

module RecordHelper
  
  def generate_id()
    Time.now.to_f.to_s.sub('.','-')
  end
  
  def logit(label)
    @log << [label, Time.now]
    #@log << [label, Time.now.strftime("%a, %d %b %Y, %H:%M%P")]        
    @log.last
  end
  
end

class ActionItem
  include RecordHelper

  attr_reader  :id

  def initialize(s, callback=nil, id: nil)
    
    @id = id || generate_id()
    @title = s
    @log = []
    @callback = callback
    
  end
  
  def done()
    logaction :completed
  end
  
  alias completed done
  
  def find(id)
    return self if id == @id
  end
  
  def log(detail: false)
    detail ? @log.map {|x| [@id, x[-1], x[0], @title]} : @log
  end
  
  def logupdate(item)
    @log << item
  end

  def to_s()
    @title
  end
  
  def started()
    logaction :started
  end
  
  def status()
    @log.last ? @log.last : []
  end
  
  def stopped()
    logaction :stopped
  end
  
  def status=(status)
    
    case status
    when :done
      done()
    when :started
      started()
    end
    
  end
  
  def to_xml()
    
    h = {id: @id, status: status().join(' ')}
    Rexle::Element.new(:action, attributes: h, value: @title)
    
  end
  
  private
  
  def logaction(label)    
    r = logit label
    @callback.status = r.clone.insert(1, @title) if @callback
  end

end

class Actions

  attr_accessor :status  
  
  def initialize(obj=nil, callback=nil)
    
    @a = read obj if obj.is_a? Rexle::Recordset
    @callback = callback
    
  end
  
  def find(id)
    @a.find {|x| x.find id}
  end

  def import(a)

    @a = a.map do |x|
      x.is_a?(String) ? ActionItem.new(x, @callback) : Actions.new(@callback).import(x)
    end

    return self

  end
  
  def log()
    @a.flat_map {|x| x.log(detail: true)}
  end  

  def [](i)
    @a[i]
  end
  
  def to_s()
    @a.each(&:to_s)
  end
  
  def to_xml()
    
    Rexle::Element.new( :actions, value: @a.map(&:to_xml).join)
    #@a.map(&:to_xml)
  end

  private
  
  def read(node)
    
    node.map do |e|
      
      case e.name.to_sym
      when :action
        ActionItem.new(e.text, id: e.attributes[:id])
      when :actions
        Actions.new(e.xpath('*'), callback: @callback)
      end
      
    end
    
  end  

end

class ResultItem
  include RecordHelper
  
  attr_reader :id
  
  def initialize(s, callback=nil, id: nil)
    @id = id || generate_id()
    @evidence = s
    @callback = callback
  end
  
  def to_s()
    @evidence
  end
  
  def to_xml()
    
    h = {id: @id}
    Rexle::Element.new(:result, attributes: h, value: @evidence)
    
  end  
  
end

class Results
  
  def initialize(obj=nil, callback: nil)
    
    @a = read obj if obj.is_a? Rexle::Recordset
    @callback = callback    
    
    return self
    
  end
  
  def import(a)

    @a = a.map do |x|
      x.is_a?(String) ? ResultItem.new(x) : Results.new.import(x)
    end

    return self

  end

  def [](i)
    @a[i]
  end
  
  def to_s()
    
    @a.map.with_index do |x, i|
      if x.is_a? ResultItem then
        x.to_s
      elsif x.is_a? Results
        x.print_row(i, indent: 0)
      end
    end.join("\n")
  end
  
  def to_xml()
    
    Rexle::Element.new( :results, value: @a.map(&:to_xml).join)

  end    
  
  def print_row(id, indent: 0)
        
    @a.map.with_index do |x, i|
      if x.is_a? ResultItem then
        ('  ' * indent) + x.to_s
      elsif x.is_a? Results
        x.print_row(i, indent: indent+1)
      end
    end.join("\n")
  end
  
  private
  
  def read(node)
    
    node.map do |e|
      
      case e.name.to_sym
      when :result
        ResultItem.new(e.text, id: e.attributes[:id])
      when :results
        Results.new(e.xpath('*'), callback: @callback)
      end
      
    end
    
  end
  
end

# task dictionary
# ----------------
# import (method) Imports a new "task" which includes a STAR document outline
# done (method) The task has been completed
# completed - alias of method *done*
# status (method) returns the most recent status from the task log
# log (attr) returns an Array object containing a timeline of status messages in chronological order
# progress (method) returns the most recent action completed or started
# duration (method) returns the actual duration
# type (attr) Frequency type e.g. (daily, weekly, monthly)
# estimate_duration (attr) OPTIONAL. the estimate duration is explicitly declared in the STAR document or is calculated from estimate durations in the actions if declared.
# actions (method) returns the Actions object
# location (attr) set or get the current physical location
# started (method) adds a status message to the log

class StarTask
  include RecordHelper

  attr_reader :situation, :task, :actions, :results, :id

  def initialize(src=nil, debug: false)
    
    @debug = debug
    @id = generate_id()
    @log = []
    @status = ''
    read src if src
    
  end
  
  def done()
    logtask :completed
  end
  
  alias completed done
  
  def find(id)
    
    if @id == id then
      return self
    else
      @actions.find id
    end
    
  end

  def import(raws)

    s, _ = RXFHelper.read raws
    puts 's: ' + s.inspect if @debug
    
    obj = if s.lstrip[0] == '#' then
    
      a = s.split(/^#+ /)
      a.shift
      
     rawh =  a.map do |x|
       
        rawlabel, body = x.split(/\n/,2)
        
        [rawlabel.rstrip.downcase.gsub(/\s+/, '_').to_sym, 
         body.strip.gsub(/^(\s*)[\*\+] /,'\1')]
        
      end.to_h
      
      h = {}
      h[:situation] = rawh[:situation]
      h[:task] = rawh[:task]
      h[:action] = {items: LineTree.new(rawh[:action]).to_a(normalize: true)}
      h[:result] = {items: LineTree.new(rawh[:result]).to_a(normalize: true)}
      h
      
    else
      s
    end
    
    puts 'obj: ' + obj.inspect if @debug
        
    kvx = Kvx.new obj
    @situation = kvx.situation
    @task = kvx.task
    @actions = Actions.new(self).import(kvx.action[:items])
    @results = Results.new(self).import(kvx.result[:items])

  end
  
  def log(detail: false)
    #todo
    detail ? @log.map {|x| [@id, x[-1], x[0]]} : @log
  end
  
  def logupdate(item)
    @log << item
  end
    
  # adds a status message to the log
  #
  def started()
    logtask :started
  end
  
  def status()
    @status
  end
  
  def status=(s)
    @status = s
  end
  
  def stopped()
    logtask :stopped
  end  
    
  def to_xml()
    
    situation = Rexle::Element.new( :situation, value: @situation)
    task = Rexle::Element.new( :task, value: @task)
    
    doc = Rexle.new()
    doc.add Rexle::Element.new(:star)
    doc.root.attributes[:id] = @id
    doc.root.add situation
    doc.root.add task
    doc.root.add @actions.to_xml
    doc.root.add @results.to_xml
    
    logx = log(detail: true) + @actions.log
    
    lognode = Rexle::Element.new(:log)
    
    logx.sort_by {|x| x[1]}.reverse.each do |x|
      
        attr = {id: x[0], timestamp: x[1]}
        val = "[%s]" % x[2]
        val += ' ' + x[3] if x[3]
        
        lognode.add Rexle::Element.new( :li, attributes: attr, value: val)
    end
    
    doc.root.add lognode
    doc.root.xml pretty: true
    
  end  
  
  private
  
  def logtask(label)
    
    r = logit label
    @status = r
    
  end
  
  def read(obj)

    s, _ = RXFHelper.read obj
    doc = Rexle.new(s)
    @id = doc.root.attributes[:id]
    @situation = doc.root.element('situation').text 
    @task = doc.root.element('task').text        
    actions = doc.root.xpath('actions/*')
    @actions = Actions.new actions
    results = doc.root.xpath('results/*')
    @results = Results.new results
    
    log = doc.root.xpath('log/*')
    
    log.reverse.each do |x|
      
      id = x.attributes[:id]
      found = find id
      
      if found then
        d = Time.parse(x.attributes[:timestamp])        
        puts 'x.text: ' + x.text.inspect if @debug
        status = x.text[/^\[([^\]]+)/,1]
        found.logupdate([status.to_sym, d])
      end
      
      
    end
    
    doc.xml pretty: true
  end

end
