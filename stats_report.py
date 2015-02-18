#!/usr/bin/env - python

import json
from collections import defaultdict
import pygal
from pygal.style import LightStyle
import sys

from pygal.style import Style
custom_style = Style(
  background='transparent',
  plot_background='transparent',
  foreground='#AAAAAA', #Legend, minor labels and major grind lines
  foreground_light='#222222', #vhart title and major labels
  foreground_dark='#DDDDDD', #minor gridlines
  opacity='1',
  opacity_hover='.9',
  transition='100ms ease-in',
  colors=('#F84040', '#12E812', '#1212E8', '#E87653', '#E89B53'))




stats=["cmd_set", "ep_diskqueue_drain", "ep_diskqueue_fill", "vb_active_ops_create", "vb_replica_ops_create", "vb_active_ops_update", "vb_replica_ops_update", "ep_queue_size", "ep_flusher_todo", "vb_active_queue_fill", "vb_active_queue_drain", "vb_replica_queue_drain", "cpu_utilization_rate", "curr_items", "ep_dcp_replica_items_remaining", "ep_dcp_replica_items_sent"]
#"ep_tap_replica_queue_backfillremaining" ] #

if len(sys.argv) != 2:
	print "Usage: " + sys.argv[0] + " <chart title>"
	sys.exit()
chart_title = sys.argv[1]

master_dict = {}
master_dict['stats'] = defaultdict(dict)
master_dict['sum']   = defaultdict(list)

for stat in stats:
  input_file = stat + '.out'
  print "Processing " + input_file
  master_dict['stats'][stat] = defaultdict(list)
  for line in open(input_file,'r'):
    my_dict  = json.loads(line)
    master_dict['timestamps']=[]
    # Find the first unique timestamp
    index = 0
    while  my_dict['timestamp'][index] in master_dict['timestamps']:
      index += 1
    master_dict['timestamps'] += my_dict['timestamp'][index:]
    node_stats = my_dict['nodeStats']
    for node_name,stats_list in node_stats.iteritems():
      master_dict['stats'][stat][node_name] += stats_list[index:]



  # Sum the individual nodes
  list_of_lists=[]
  for node, stats_list in master_dict['stats'][stat].iteritems():
    list_of_lists.append(stats_list)
  master_dict['sum'][stat] = [sum(item) for item in zip(*list_of_lists)]
  # # remove leading junk
  master_dict['sum'][stat] = master_dict['sum'][stat][60:]
  #master_dict['sum'][stat] =   master_dict['sum'][stat][:-30]
  # # remove trailing zeros
  # while master_dict['sum'][stat][-1] == 0:
  #   master_dict['sum'][stat] =   master_dict['sum'][stat][:-2]


master_dict['sum']['dwq'] = [sum(item) for item in zip(master_dict['sum']['ep_flusher_todo'], master_dict['sum']['ep_queue_size'])]

# Print columnar data
# index = 0
# for timestamp in master_dict['timestamps']:
#   print timestamp,
#   for key, val in master_dict['nodes'].iteritems():
#     print "," ,val[index],
#   print
#   index += 1

# print "time",
# for timestamp in master_dict['timestamps']:
#   print ",",timestamp,
# print
# for key, val in master_dict['nodes'].iteritems():
#   print key,
#   for elem in val:
#     print ",",elem,
#   print
print
line_chart = pygal.Line(show_dots=False,width=800,height=400,margin=5,style=custom_style)
line_chart.title = chart_title
#line_chart.y_labels=range(0,14000000,100000)
line_chart.x_labels=map(str,range(0,len(master_dict['sum']['cmd_set']),30))
line_chart.add('ops', master_dict['sum']['cmd_set'])
line_chart.add('disk_fill_rate',  master_dict['sum']['ep_diskqueue_fill'])
line_chart.add('disk_drain_rate', master_dict['sum']['ep_diskqueue_drain'])
line_chart.render_to_file('summary.svg')
line_chart.render_to_png('summary.png')

# Create DWQ + DCP queue graph
line_chart.add('write_queue', master_dict['sum']['dwq'], secondary=False)
#line_chart.add('TAP queue', master_dict['sum']['ep_tap_replica_queue_backfillremaining'], secondary=False)
line_chart.add('DCP queue', master_dict['sum']['ep_dcp_replica_items_remaining'], secondary=False)

line_chart.render_to_file('summary_with_queue.svg')
line_chart.render_to_png('summary_with_queue.png')

cpu_chart = pygal.Line(show_dots=False,width=1200,height=200,margin=5,style=custom_style,range=(50,100))
for node,stats in   master_dict['stats']['cpu_utilization_rate'].iteritems():
  cpu_chart.add(node, stats)
cpu_chart.render_to_file('cpu_summary.svg')
