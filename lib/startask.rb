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
    @log << [label, Time.now.strftime("%H:%M%P")]    
    @log.last
  end
  
end

class ActionItem
  include RecordHelper

  attr_reader :log, :id

  def initialize(s, callback=nil)
    
    @id = generate_id()
    @title = s
    @log = []
    @callback = callback
    
  end
  
  def done()
    logaction :completed
  end
  
  alias completed done

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
  
  def initialize(callback=nil)
    @callback = callback
  end

  def import(a)

    @a = a.map do |x|
      x.is_a?(String) ? ActionItem.new(x, @callback) : Actions.new(@callback).import(x)
    end

    return self

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

end

class ResultItem
  include RecordHelper
  
  attr_reader :id
  
  def initialize(s, callback=nil)
    @id = generate_id()
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
  
  def initialize(callback=nil)
    @callback = callback
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
    
    if @a.length < 2 then      
      @a[0].to_xml
    else
      Rexle::Element.new( :results, value: @a.map(&:to_xml).join)
    end
          
    #@a.map(&:to_xml)
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

  attr_reader :situation, :task, :actions, :log, :results, :id

  def initialize(src=nil, debug: false)
    
    @debug = debug
    @id = generate_id()
    @log = []
    @status = ''
    import src if src
  end
  
  def done()
    logtask :completed
  end
  
  alias completed done

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
    
    doc = Rexle.new('<star/>')
    doc.root.add situation
    doc.root.add task
    doc.root.add @actions.to_xml
    doc.root.add @results.to_xml
    doc.root.xml pretty: true
    
  end  
  
  private
  
  def logtask(label)
    
    r = logit label
    @status = r
    
  end

end
