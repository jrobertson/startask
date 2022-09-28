!#/usr/bin/env ruby

# file: startask.rb
# description: An experimental gem representing the STAR technique.

require 'kvx'
require 'rxfhelper'

class ActionItem

  attr_reader :log

  def initialize(s)
    @title = s
    @log = []
  end
  
  def done()
    logit :completed
  end
  
  alias completed done

  def to_s()
    @title
  end
  
  def started()
    logit :started
  end
  
  def status()
    @log.last
  end
  
  def stopped()
    logit :stopped
  end
  
  def status=(status)
    
    case status
    when :done
      done()
    when :started
      started()
    end
    
  end
  
  private
  
  def logit(label)
    @log << [label, Time.now.strftime("%H:%M%P")]    
  end

end

class Actions

  def import(a)

    @a = a.map do |x|
      x.is_a?(String) ? ActionItem.new(x) : Actions.new.import(x)
    end

    return self

  end

  def [](i)
    @a[i]
  end
  
  def to_s()
    @a.each(&:to_s)
  end

end

class ResultItem
  
  def initialize(s)
    @evidence = s
  end
  
  def to_s()
    @evidence
  end
  
end

class Results
  
  def initialize()

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

  attr_reader :situation, :task, :actions, :log, :results

  def initialize(src=nil, debug: false)
    @debug = debug
    @log = []
    import src if src
  end
  
  def done()
    logit :completed
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
        
        [rawlabel.downcase.gsub(/\s+/, '_').to_sym, 
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
    @actions = Actions.new.import(kvx.action[:items])
    @results = Results.new.import(kvx.result[:items])

  end
    
  # adds a status message to the log
  #
  def started()
    logit :started
  end
  
  def status()
    @log.last
  end
  
  def stopped()
    logit :stopped
  end
  
  private
  
  def logit(label)
    @log << [label, Time.now.strftime("%H:%M%P")]    
    return label
  end

end
