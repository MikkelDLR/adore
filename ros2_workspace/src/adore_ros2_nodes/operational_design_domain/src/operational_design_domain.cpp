/********************************************************************************
 * Copyright (c) 2025 Contributors to the Eclipse Foundation
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * https://www.eclipse.org/legal/epl-2.0
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

#include "operational_design_domain.hpp"
#include <csignal>
#include "adore_ros2_msgs/msg/odd.hpp"
#include "adore_ros2_msgs/msg/vehicle_info.hpp"

namespace adore
{

OperationalDeisngDomain::OperationalDeisngDomain( const rclcpp::NodeOptions& opts ) :
  rclcpp::Node{ "operational_design_domain", opts }
{
  load_parameters();
  setup_subscribers();
  setup_publishers();
}

void OperationalDeisngDomain::load_parameters()
{
  std::string openodd_file = declare_parameter<std::string>( "openodd_file", "" );

  if ( openodd_file == "" )
  {
    throw std::runtime_error( "Error when loading ODD file, no path was entered!");
  }

  // @TODO, add support for different openodd file types (yaml, xml?)
  load_json_odd_file(openodd_file);
}

void OperationalDeisngDomain::load_json_odd_file(const std::string& odd_file_path)
{
    std::ifstream ifs( odd_file_path );
    if( !ifs.is_open() )
    {
      throw std::runtime_error( "Could not open file: " + odd_file_path );
    }
    nlohmann::json j;
    ifs >> j;

    if ( j.contains("max_speed") )
    {
      odd.max_speed = j.at("max_speed").get<double>();
    }
}

void OperationalDeisngDomain::setup_subscribers()
{
  timer = create_wall_timer( std::chrono::milliseconds( static_cast<int>( 100 ) ), // 10 Hz
                             std::bind( &OperationalDeisngDomain::timer_callback, this ) );

  subscriber_vehicle_info = create_subscription<adore_ros2_msgs::msg::VehicleInfo>( "vehicle_info", 1,
                                      [this](const adore_ros2_msgs::msg::VehicleInfo& msg) {  latest_vehicle_info = msg; });
}

void OperationalDeisngDomain::setup_publishers()
{
  publisher_odd = create_publisher<adore_ros2_msgs::msg::Odd>( "odd", 1 );
}

void OperationalDeisngDomain::timer_callback()
{
  std::optional<Violation> odd_violation = evaluate_odd();

  adore_ros2_msgs::msg::Odd odd_msgs;

  if ( odd_violation.has_value() )
  {
    odd_msgs.matching = false;
    odd_msgs.status = odd_violation.value();
    publisher_odd->publish( odd_msgs );
    return;
  }

  odd_msgs.matching = true;
  odd_msgs.status = "ODD/COD match";
  publisher_odd->publish( odd_msgs );
}

std::optional<Violation> OperationalDeisngDomain::evaluate_odd()
{
  Violation violation = "";
  
  evaluate_max_speed(violation);

  if ( violation.empty() )
  {
    return {};
  }

  return violation;
}

void OperationalDeisngDomain::evaluate_max_speed(Violation& violation)
{
  if ( !odd.max_speed.has_value() )
    return;

  if ( !latest_vehicle_info.has_value() )
  {
    violation += "vehicle's current or max speed could not be read, ";
    return;
  }

  if ( latest_vehicle_info.value().max_speed > odd.max_speed.value() )
  {
    violation += "vehicle's max speed is higher than defined odd max speed, ";
  }

  if ( latest_vehicle_info.value().speed > odd.max_speed.value() )
  {
    violation += "vehicle's current speed is higher than defined odd max speed, ";
  }
  
  return;
}

} // namespace adore
