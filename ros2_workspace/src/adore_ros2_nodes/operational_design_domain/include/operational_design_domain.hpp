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

#pragma once

#include <rclcpp/rclcpp.hpp>

#include <nlohmann/json.hpp>
#include <fstream>
#include "optional"
#include <string>
#include "adore_ros2_msgs/msg/odd.hpp" // @TODO, find a better name
#include "adore_ros2_msgs/msg/vehicle_info.hpp"

using Violation = std::string;

namespace adore
{

struct ODD
{
  std::optional<double> max_speed;
};

class OperationalDeisngDomain : public rclcpp::Node
{
  public:

    explicit OperationalDeisngDomain( const rclcpp::NodeOptions& opts );


  private:

    rclcpp::Publisher<adore_ros2_msgs::msg::Odd>::SharedPtr publisher_odd;

    rclcpp::Subscription<adore_ros2_msgs::msg::VehicleInfo>::SharedPtr subscriber_vehicle_info;

    ODD odd;

    void load_parameters();
    void load_json_odd_file(const std::string& odd_file_path);

    void setup_subscribers();
    void setup_publishers();

    rclcpp::TimerBase::SharedPtr timer;
    void timer_callback();
    std::optional<Violation> evaluate_odd();

    void evaluate_max_speed(Violation& violation);

    std::optional<adore_ros2_msgs::msg::VehicleInfo> latest_vehicle_info;
};


} // namespace adore




