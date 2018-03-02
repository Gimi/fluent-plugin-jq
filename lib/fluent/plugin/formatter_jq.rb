# frozen_string_literal: true

# Copyright 2018- Zhimin (Gimi) Liang (https://github.com/Gimi)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/formatter"

module Fluent
  module Plugin
    class JqFormatter < Fluent::Plugin::Formatter
      Fluent::Plugin.register_formatter("jq", self)

      desc 'The jq program used to format income events. The result of the program should only return one item of any kind (a string, an array, an object, etc.). If it returns multiple items, only the first will be used.'
      config_param :jq, :string, default: nil

      desc 'The jq program used to format income events. The result of the program should only return one item of any kind (a string, an array, an object, etc.). If it returns multiple items, only the first will be used. DEPRECATED.'
      config_param :jq_program, :string, deprecated: 'use jq instead.', default: nil

      desc 'Defines the behavior on error happens when formatting an event. "skip" will skip the event; "ignore" will ignore the error and return the JSON representation of the original event; "raise_error" will raise a RuntimeError.'
      config_param :on_error, :enum, list: [:skip, :ignore, :raise_error], default: :ignore

      def initialize
	super
	require "jq"
      end

      def configure(conf)
	super

	@jq = @jq_program unless @jq
	raise Fluent::ConfigError, "jq is required." unless @jq

	JQ::Core.new @jq
      rescue JQ::Error
	raise Fluent::ConfigError, "Could not parse jq filter #{@jq}, error: #{$!.message}"
      end

      def format(tag, time, record)
	item = JQ(MultiJson.dump(record)).search(@jq).first
	return item if item.instance_of?(String)
	MultiJson.dump item
      rescue JQ::Error
	msg = "Failed to format #{record.to_json} with #{@jq}, error: #{$!.message}"
	log.error msg
	case @on_error
	when :skip
	  return ''
	when :ignore
	  return record.to_json
	when :raise_error
	  raise msg
	end
      end
    end
  end
end
